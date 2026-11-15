# Bootstrap 5.3 todavía usa @import, que Dart Sass marca como obsoleto.
# Silenciamos esos avisos de compilación (no afectan al CSS generado).
Rails.application.config.dartsass.build_options += [ "--quiet-deps", "--silence-deprecation=import" ]
