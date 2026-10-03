const String _adminConsoleToken = 'ops-9d4b1c83f6a24715';
const String adminConsolePath = '/_console/$_adminConsoleToken';

bool isAdminConsoleUri(Uri uri) {
  final location = uri.fragment.isNotEmpty ? uri.fragment : uri.path;
  final parsed = Uri.tryParse(location);
  if (parsed == null) return false;
  return parsed.path == adminConsolePath ||
      parsed.path == '$adminConsolePath/login';
}

Uri adminConsoleUri(Uri base) =>
    base.replace(fragment: '$adminConsolePath/login');
