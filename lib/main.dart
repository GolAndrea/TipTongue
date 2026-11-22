import 'package:flutter/material.dart';

import 'data/repositories/settings_repository.dart';
import 'data/services/ai_predictor_service.dart';
import 'data/services/glasses_connection_service.dart';
import 'data/services/speech_input_service.dart';
import 'data/services/whisper_tts_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/session/view_models/session_view_model.dart';
import 'ui/features/session/views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final viewModel = SessionViewModel(
    settingsRepository: SettingsRepository(),
    glassesService: GlassesConnectionService(),
    speechService: SpeechInputService(),
    whisperService: WhisperTtsService(),
    predictorService: AiPredictorService(),
  )..init();

  runApp(TipOnMyTongueApp(viewModel: viewModel));
}

class TipOnMyTongueApp extends StatelessWidget {
  const TipOnMyTongueApp({super.key, required this.viewModel});

  final SessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TipTongue',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.warmLight(),
      darkTheme: AppTheme.warmDark(),
      themeMode: ThemeMode.light,
      home: HomeScreen(viewModel: viewModel),
    );
  }
}
