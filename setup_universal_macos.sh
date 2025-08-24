#!/bin/bash

# Universal macOS Setup Script for PSVB HR System Flutter Project
# This script will work on ANY macOS system (Intel/Apple Silicon)

echo "🚀 Setting up PSVB HR System Flutter Project for Universal macOS Compatibility"
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only!"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    print_status "Detected Apple Silicon (M1/M2/M3) Mac"
    HOMEBREW_PREFIX="/opt/homebrew"
else
    print_status "Detected Intel Mac"
    HOMEBREW_PREFIX="/usr/local"
fi

print_status "Starting universal setup process..."

# Step 1: Install Xcode Command Line Tools
print_status "Step 1: Installing Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    print_status "Installing Xcode Command Line Tools (this may take several minutes)..."
    xcode-select --install
    print_warning "Please wait for Xcode installation to complete, then press any key to continue..."
    read -n 1 -s
else
    print_success "Xcode Command Line Tools already installed"
fi

# Step 2: Install Homebrew
print_status "Step 2: Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH based on architecture
    if [[ "$ARCH" == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    print_success "Homebrew installed successfully"
else
    print_success "Homebrew already installed"
fi

# Step 3: Install Flutter
print_status "Step 3: Installing Flutter..."
if ! command -v flutter &> /dev/null; then
    print_status "Installing Flutter via Homebrew..."
    brew install --cask flutter
    print_success "Flutter installed successfully"
else
    print_success "Flutter already installed"
fi

# Step 4: Install Java Development Kit
print_status "Step 4: Installing Java Development Kit..."
if ! command -v java &> /dev/null; then
    print_status "Installing Temurin JDK..."
    brew install --cask temurin
    print_success "Java installed successfully"
else
    print_success "Java already installed"
fi

# Step 5: Install CocoaPods
print_status "Step 5: Installing CocoaPods..."
if ! command -v pod &> /dev/null; then
    print_status "Installing CocoaPods..."
    sudo gem install cocoapods
    print_success "CocoaPods installed successfully"
else
    print_success "CocoaPods already installed"
fi

# Step 6: Install Android Studio (optional but recommended)
print_status "Step 6: Installing Android Studio..."
if ! [ -d "/Applications/Android Studio.app" ]; then
    print_status "Installing Android Studio..."
    brew install --cask android-studio
    print_warning "Android Studio installed. Please open it and complete the setup wizard."
    print_warning "Install Android SDK (API level 21+) from Tools > SDK Manager"
else
    print_success "Android Studio already installed"
fi

# Step 7: Configure Flutter
print_status "Step 7: Configuring Flutter..."
flutter doctor

# Step 8: Navigate to project directory
print_status "Step 8: Setting up project..."
cd "$(dirname "$0")"

# Step 9: Clean and setup project
print_status "Step 9: Setting up project dependencies..."
flutter clean
flutter pub get

# Step 10: Generate localization files
print_status "Step 10: Generating localization files..."
flutter gen-l10n

# Step 11: Generate Hive adapters
print_status "Step 11: Generating Hive database adapters..."
flutter packages pub run build_runner build --delete-conflicting-outputs

# Step 12: Setup iOS
print_status "Step 12: Setting up iOS..."
cd ios
pod install
cd ..

# Step 13: Final verification
print_status "Step 13: Final verification..."
flutter doctor

print_success "🎉 Setup completed successfully!"
echo ""
echo "📱 To run your project:"
echo "   iOS Simulator: flutter run -d ios"
echo "   Android: flutter run -d android"
echo ""
echo "🔧 If you encounter any issues:"
echo "   1. Run: flutter doctor"
echo "   2. Check: flutter pub get"
echo "   3. Regenerate: flutter gen-l10n"
echo ""
echo "📚 For more help, visit: https://flutter.dev/docs"
echo ""
print_success "Your PSVB HR System is now ready to run on any macOS system! 🚀"
