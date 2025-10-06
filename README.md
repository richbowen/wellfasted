# WellFasted 🌟

An intelligent intermittent fasting tracker with AI-powered meal recommendations.

## Features

- ⏱️ Customizable fasting timers (16:8, 18:6, or custom durations)
- 🤖 AI-powered meal recommendations using Google Gemini
- 📱 Cross-platform notifications (Android, iOS, macOS)
- 📊 Fasting history tracking
- 🎨 Beautiful Material 3 dark theme
- 🔒 Secure environment variable configuration

## Getting Started

### Prerequisites

- Flutter SDK (latest stable)
- Google Gemini API key for AI recommendations

### Environment Variables

This app uses environment variables for secure configuration. **Never commit API keys to version control.**

#### Required Variables

- `GEMINI_API_KEY` - Your Google Gemini API key
- `ENV` - Application environment (`development`, `staging`, `production`)

#### Optional Variables

- `GEMINI_API_URL` - Custom Gemini API endpoint (uses default if not set)

### Running the App

#### Development Mode

```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here --dart-define=ENV=development
```

#### Production Mode

```bash
flutter run --dart-define=GEMINI_API_KEY=your_api_key_here --dart-define=ENV=production
```

### Building for Release

#### Debug APK

```bash
flutter build apk --debug \
  --dart-define=GEMINI_API_KEY=your_api_key_here \
  --dart-define=ENV=development
```

#### Release APK

```bash
flutter build apk --release \
  --dart-define=GEMINI_API_KEY=your_api_key_here \
  --dart-define=ENV=production
```

### Setup Script

Use the provided setup script for easy configuration:

```bash
chmod +x scripts/run_with_env.sh
./scripts/run_with_env.sh  # Shows all available commands
```

## Configuration

The app automatically configures itself based on the environment:

- **Development**: Debug logging enabled, shows "(Dev)" in app name
- **Staging**: Staging configuration, shows "(Staging)" in app name
- **Production**: Optimized for release, minimal logging

## API Key Setup

1. Get a Google Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Never commit the API key to version control
3. Use different keys for different environments
4. In CI/CD, store keys as repository secrets

## CI/CD

The GitHub Actions workflow automatically builds the app with environment variables. Add your API key as a repository secret named `GEMINI_API_KEY`.

## Development

### Project Structure

```
lib/
├── config/
│   └── app_config.dart     # Environment configuration
├── main.dart               # Main application
└── ...
```

### Adding New Environment Variables

1. Add the variable to `lib/config/app_config.dart`
2. Use `String.fromEnvironment()` with a sensible default
3. Update the GitHub workflow if needed
4. Document the new variable in this README

## Contributing

1. Fork the repository
2. Create a feature branch
3. Never commit API keys or sensitive data
4. Test with different environments
5. Submit a pull request

## License

This project is licensed under the MIT License.
