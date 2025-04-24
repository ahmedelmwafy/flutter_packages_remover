# flutter_packages_remover

A command-line tool to help identify and interactively remove unused packages from your Dart/Flutter project's `pubspec.yaml`.

---

## ✨ Features

- 🔍 **Detect unused packages** by scanning Dart/Flutter files for import usage.
- 🧹 **Interactive cleanup**: Choose which unused packages to keep or remove via an intuitive selection interface.
- 💾 **Automatic backup** of your `pubspec.yaml` before making any changes.

---

## 🚀 Getting Started

### 📦 Installation

1. Clone the repository:

    ```bash
    git clone https://github.com/ahmedelmwafy/flutter_packages_remover.git
    cd flutter_packages_remover
    ```

2. Optionally, activate the tool globally:

    ```bash
    dart pub global activate --source path .
    ```

---

## 🛠 Usage

Navigate to the root directory of the Dart/Flutter project containing the `pubspec.yaml` you want to clean.


### Interactively remove unused packages

To remove unused packages interactively, run:

```bash
flutter_packages_remover --remove
```

The tool will display unused packages with corresponding numbers and prompt you to select the ones you wish to keep.
