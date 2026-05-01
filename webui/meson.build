project('nixfiles-webui', 'rust',
  version: '0.1.0',
  default_options: ['warning_level=2']
)

executable('nixfiles-webui',
  'src/main.rs',
  'src/http.rs',
  'src/model.rs',
  'src/state.rs',
  'src/views/mod.rs',
  'src/views/html.rs',
  'src/views/style.rs',
  install: true,
)

test_exe = executable('nixfiles-webui-tests',
  'src/tests.rs',
  'src/http.rs',
  'src/model.rs',
  'src/state.rs',
  rust_args: ['--test'],
  install: false,
)

test('unit-tests', test_exe)
