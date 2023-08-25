# gitlab-ci

Вспомогательные функции для сборки и доставки модулей Deckhouse при помощи Gitlab CI.

## Основная идея

В этом репозитории лежит код для шаблонов заданий Gitlab CI, который можно переиспользовать. Шаблоны лежат в папке [`templates`](templates/).

Чтобы подключить шаблон, в `.gitlab-ci.yml` нужно добавить стледующий код:

```yaml
include:
- project: 'deckhouse/modules/gitlab-ci'
  ref: main
  file: '/templates/Setup.gitlab-ci.yml'
- project: 'deckhouse/modules/gitlab-ci'
  ref: main
  file: '/templates/Build.gitlab-ci.yml'

Build:
  extends: .build
  tags:
  - my-runner
```

> Вместо `ref: main` можно указать конкретный коммит, чтобы изменения не влияли на ваш CI.


В папке [`examples`](examples/) лежат примеры `.gitlab-ci.yml`, которые можно собрать из шаблонов.
