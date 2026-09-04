import '../version_info.dart';

/// User-Agent, отправляемый на каждый HTTP-fetch подписки.
///
/// **Зачем это важно.** Часть subscription-панелей (Remnawave / Marzban-типа)
/// маршрутизирует тело ответа по подстроке в User-Agent: клиента, опознанного
/// панелью, кормят base64/URI-списком, который парсер v2 умеет ингестить;
/// неопознанному клиенту панель может отдать полный sing-box JSON-конфиг
/// (`{dns,route,inbounds,outbounds,...}`) или generic-заглушку.
///
/// §368 — полный конфиг парсер теперь **разбирает** (узлы, группы, detour), так
/// что добавление подписки на нём больше не падает. UA всё равно оставляем
/// брендовым: base64/URI-list — более компактный и полный ответ панели, а из
/// конфига мы берём только транспортный слой.
///
/// Эмпирически (боевая панель `sub.vern13.ru`): UA с голым `singbox` (без
/// дефиса) → JSON-объект; UA с подстрокой `DARK` → base64 URI-list. Поэтому
/// бренд-токена `DARK-android` достаточно для распознавания — ни `sing-box`,
/// ни платформенный комментарий не нужны (см. таск 114).
///
/// Инварианты:
///   1. бренд-токен начинается с `DARK-android/` — по нему панель опознаёт
///      клиента и отдаёт base64/URI-list; суффикс `-android` отличает от
///      десктопной сборки `DARK-desktop`;
///   2. голой подстроки `singbox` (без дефиса) нет нигде — именно она триггерит
///      неправильную маршрутизацию (см. regression-тест в
///      `test/subscription/user_agent_test.dart`).
///
/// Формат:
///
/// ```
/// DARK-android/<appVersion>
/// ```
///
/// например `DARK-android/2.0.4`.

const _kProductToken = 'DARK-android';

// §219 — module-level: раньше компилился на каждый вызов _sanitizeToken
// (в т.ч. при инициализации приложения).
final _uaSanitizeRe = RegExp(r'[()\s;]+');

/// Чистая функция-конструктор UA. Подставляет версию и гарантирует инварианты
/// независимо от мусора на входе. Вынесена отдельно ради regression-теста.
String buildSubscriptionUserAgent({required String appVersion}) {
  final ver = _sanitizeToken(appVersion, fallback: 'unknown');
  return '$_kProductToken/$ver';
}

/// Срезает ведущий `v` и символы, которые сломали бы структуру UA (скобки /
/// точка-с-запятой / пробелы). На пустом результате — [fallback], чтобы
/// инварианты держались даже до инициализации версии.
String _sanitizeToken(String raw, {required String fallback}) {
  var s = raw.trim();
  if (s.startsWith('v')) s = s.substring(1);
  s = s.replaceAll(_uaSanitizeRe, '');
  return s.isEmpty ? fallback : s;
}

/// Резолвит UA из версии приложения ([VersionInfo], инициализируется в `main()`
/// до `runApp`). Синхронно — runtime-источников за пределами версии больше нет.
String resolveSubscriptionUserAgent() =>
    buildSubscriptionUserAgent(appVersion: VersionInfo.I.version);
