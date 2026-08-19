<img width="1500" height="500" alt="profile-header" src="https://github.com/user-attachments/assets/bf685313-3569-4c60-8897-fb31527b3032" />

# Transl 🌐

A fast, native, and lightweight pop-up translation utility for macOS.

Transl translates selected text instantly without breaking your workflow. Highlight text anywhere, press **Option + T** (⌥T), and a floating translation panel appears right next to your mouse cursor.

---

## ✨ Features

- **Instant Pop-Up:** Select text in any app and press `Option + T` (⌥T) to show the translation at your cursor.
- **Smart Auto-Switching:** Detects the source language automatically and toggles between target and fallback languages.
- **Non-Intrusive Panel:** Floating panel stays on top without stealing focus from your active window.
- **Auto-Copy Option:** Automatically copy translations to the clipboard or copy manually with a single click.
- **Ultra Lightweight:** Takes up ~4 MB of disk space and ~55 MB of RAM in the background.

---

## 📦 Installation

1. Download the latest `.dmg` file from the [Releases](../../releases) section.
2. Open the `.dmg` and drag **Transl.app** into your **Applications** folder.
3. Launch **Transl**.

---

## 🛡️ Bypassing macOS Security (Unsigned App)

Since Transl is an independent open-source project without a paid Apple Developer ID, macOS Gatekeeper may show a warning: *"Transl is damaged and can’t be opened"* or *"App cannot be opened because it is from an unidentified developer"*.

You can bypass this in two ways:

### Option 1: Terminal Command (Recommended)
Open **Terminal** and run:

```bash
xattr -cr /Applications/Transl.app
```

### Option 2: System Settings
1. Try opening **Transl.app** once.
2. Go to **System Settings** -> **Privacy & Security**.
3. Scroll down to the **Security** section where it mentions Transl was blocked.
4. Click **Open Anyway** and enter your password.

---

## 🔑 Permissions

Transl requires Accessibility permission to capture highlighted text from other applications:

1. Open **System Settings** -> **Privacy & Security** -> **Accessibility**.
2. Enable the toggle for **Transl**.

---

## 💬 Community & Support

Join the Discord server to share feedback, report issues, or follow updates:

- **General:** Discussions about macOS utilities and development.
- **Bug Reports:** Report bugs or app crashes.
- **Feature Requests:** Share ideas for future releases.

👉 [Join Discord Server](https://discord.gg/SPM8Fj4xsh)

---

## 🔗 Other Projects

- **[Clips](https://github.com/roulq/Clips)** — A fast, modern, and lightweight clipboard manager for macOS.

---

## 📄 License

Distributed under the **GPLv3 License**. See `LICENSE` for details.

<img width="1920" height="1080" alt="474_1x_shots_so" src="https://github.com/user-attachments/assets/4bba821b-07e6-4c96-9d39-4fec432cc541" />
