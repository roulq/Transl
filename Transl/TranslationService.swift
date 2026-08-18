import Foundation

enum TranslationResult {
    case success(String)
    case failure(String)

    var translatedText: String? {
        switch self {
        case .success(let t): return t
        case .failure: return nil
        }
    }

    var errorMessage: String? {
        switch self {
        case .success: return nil
        case .failure(let e): return e
        }
    }
}

final class TranslationService {
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept": "*/*",
            "Accept-Language": "en-US,en;q=0.9",
            "Referer": "https://translate.google.com/"
        ]
        return URLSession(configuration: config)
    }()

    func translate(text: String, targetLanguageCode: String) async -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(LocalizationManager.localized("error.empty_text"))
        }

        let maxLen = 4800
        let chunked = chunk(trimmed, maxLength: maxLen)

        var translatedParts: [String] = []
        for chunk in chunked {
            let r = await translateSingle(chunk, target: targetLanguageCode)
            switch r {
            case .success(let t): translatedParts.append(t)
            case .failure(let e): return .failure(e)
            }
        }

        return .success(translatedParts.joined(separator: " "))
    }

    func translateWithFallback(text: String, targetLanguageCode: String, fallbackLanguageCode: String) async -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(LocalizationManager.localized("error.empty_text"))
        }

        let detectResult = await detectLanguage(text: trimmed)
        let detectedLanguage = detectResult ?? "auto"

        if detectedLanguage == targetLanguageCode {
            return await translate(text: text, targetLanguageCode: fallbackLanguageCode)
        }

        return await translate(text: text, targetLanguageCode: targetLanguageCode)
    }

    private func detectLanguage(text: String) async -> String? {
        guard let raw = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlStr = "https://translate.googleapis.com/translate_a/single"
            + "?client=gtx"
            + "&sl=auto"
            + "&tl=en"
            + "&dt=t"

        guard let url = URL(string: urlStr + "&q=\(raw)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard !data.isEmpty else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
               json.count >= 3,
               let detectedLang = json[2] as? String {
                return detectedLang
            }
        } catch {
            return nil
        }

        return nil
    }

    private func chunk(_ text: String, maxLength: Int) -> [String] {
        if text.count <= maxLength { return [text] }
        var result: [String] = []
        var current = ""
        let delimiters = CharacterSet(charactersIn: ".!?\n。！？")
        for ch in text {
            current.append(ch)
            if current.count >= maxLength {
                let ns = current as NSString
                let range = ns.rangeOfCharacter(from: delimiters, options: .backwards)
                if range.location != NSNotFound {
                    let splitAt = range.location + 1
                    result.append(ns.substring(to: splitAt))
                    current = ns.substring(from: splitAt)
                } else {
                    result.append(current)
                    current = ""
                }
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func translateSingle(_ text: String, target: String) async -> TranslationResult {
        guard let raw = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return .failure(LocalizationManager.localized("error.encoding_failed"))
        }
        let urlStr = "https://translate.googleapis.com/translate_a/single"
            + "?client=gtx"
            + "&sl=auto"
            + "&tl=\(target)"
            + "&hl=en"
            + "&dt=t"
            + "&dt=bd"
            + "&dj=1"
            + "&source=icon"
            + "&q=\(raw)"

        guard let url = URL(string: urlStr) else {
            return .failure(LocalizationManager.localized("error.invalid_url"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(LocalizationManager.localized("error.no_response"))
            }
            guard (200...299).contains(http.statusCode) else {
                return .failure(LocalizationManager.localized("error.http_error", String(http.statusCode)))
            }
            guard !data.isEmpty else {
                return .failure(LocalizationManager.localized("error.empty_response"))
            }
            return parseGoogleResponse(data: data, fallbackText: text)
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                return .failure(LocalizationManager.localized("error.network_error", ns.localizedDescription))
            }
            return .failure(LocalizationManager.localized("error.parsing_error", ns.localizedDescription))
        }
    }

    private func parseGoogleResponse(data: Data, fallbackText: String) -> TranslationResult {
        if let viaDecodable = try? JSONDecoder().decode(GoogleTranslationResponse.self, from: data) {
            let sentences = viaDecodable.sentences ?? []
            let joined = sentences
                .compactMap { $0.trans }
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                return .success(joined)
            }
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                return parseLegacyNestedArray(data: data, fallbackText: fallbackText)
            }
            if let sentences = json["sentences"] as? [[String: Any]] {
                let text = sentences.compactMap { $0["trans"] as? String }.joined()
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return .success(trimmed) }
            }
            return parseLegacyNestedArray(data: data, fallbackText: fallbackText)
        } catch {
            return parseLegacyNestedArray(data: data, fallbackText: fallbackText)
        }
    }

    private func parseLegacyNestedArray(data: Data, fallbackText _: String) -> TranslationResult {
        do {
            guard let root = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] else {
                return .failure(LocalizationManager.localized("error.response_parsing_failed"))
            }
            guard let first = root.first as? [[Any]] else {
                return .failure(LocalizationManager.localized("error.unexpected_response_format"))
            }
            var parts: [String] = []
            for row in first {
                guard row.count >= 2, let translated = row[0] as? String else { continue }
                parts.append(translated)
            }
            let joined = parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if joined.isEmpty {
                return .failure(LocalizationManager.localized("error.translation_not_found"))
            }
            return .success(joined)
        } catch {
            return .failure(LocalizationManager.localized("error.parsing_error", error.localizedDescription))
        }
    }

    static var availableLanguages: [LanguageOption] {
        let codes: [(code: String, name: String)] = [
            ("ru", "Русский"),
            ("en", "English"),
            ("de", "Deutsch"),
            ("fr", "Français"),
            ("es", "Español"),
            ("it", "Italiano"),
            ("zh-CN", "中文 (简体)"),
            ("zh-TW", "中文 (繁體)"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("pt", "Português"),
            ("ar", "العربية"),
            ("tr", "Türkçe"),
            ("uk", "Українська"),
            ("pl", "Polski"),
            ("nl", "Nederlands"),
            ("sv", "Svenska"),
            ("no", "Norsk"),
            ("da", "Dansk"),
            ("fi", "Suomi"),
            ("cs", "Čeština"),
            ("ro", "Română"),
            ("hu", "Magyar"),
            ("bg", "Български"),
            ("el", "Ελληνικά"),
            ("hi", "हिन्दी"),
            ("vi", "Tiếng Việt"),
            ("th", "ไทย"),
            ("id", "Indonesia"),
            ("ms", "Bahasa Melayu")
        ]
        return codes.map { LanguageOption(code: $0.code, name: $0.name) }
    }
}

private struct GoogleTranslationResponse: Decodable {
    let sentences: [GoogleSentence]?
}

private struct GoogleSentence: Decodable {
    let trans: String?
}

struct LanguageOption: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
}
