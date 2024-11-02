// lib/env/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: 'lib/.env')
abstract class Env {
    @EnviedField(varName: 'GPT_API_KEY', obfuscate: true)
    static String GPT_API_KEY = _Env.GPT_API_KEY;
    @EnviedField(varName: 'GPT_API_URL', obfuscate: true)
    static String GPT_API_URL = _Env.GPT_API_URL;
}