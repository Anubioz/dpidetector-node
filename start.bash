#!/usr/bin/env bash

source .common.bash

PARALLEL="${PARALLEL:+--parallel ${PARALLEL}}"

checkutil docker || die "Не получается найти утилиту 'docker' (без неё невозможно запустить данное ПО)"

function dkrup() {
  case "${1}" in
    plugin)
      compose=("docker" "compose" "${PARALLEL}")
      up_args=("--no-log-prefix")
      ;;
    old)
      compose=("docker-compose")
      unset PARALLEL
      ;;
  esac
  if ! ${compose[*]} pull; then # --quiet
    nonfatal die "Обновление из готовых образов не удалось (см. ошибку выше)."
    if [[ -n "${DPIDETECTOR_FORCE_BUILD}" ]]; then
      nonfatal die "Будет произведена локальная сборка контейнеров" \
        "(однако, пожалуйста, сообщите о случившемся в чат)"
      ${compose[*]} build --pull --no-cache || die "Сборка провалилась"
    else
      die "Пожалуйста, напишите об этом в чат!"
    fi
  fi
  ${compose[*]} up ${up_args[*]} --remove-orphans --detach --force-recreate
}

save_version $(released_version)

if [[ -f /usr/libexec/docker/cli-plugins/docker-compose ]]; then
  dkrup plugin
else
  nonfatal die "Не обнаружен Compose V2 (плагин для docker)."
  nonfatal die "Будет произведена попытка использовать устаревший docker-compose."
  nonfatal die "Однако его работа не гарантируется. Рекомендуется установить новый стек (см. README)"
  checkutil docker-compose || die "Не получается найти ни плагин compose для docker, ни утилиту 'docker-compose'" \
    "(без хотя бы одного из них невозможно запустить данное ПО)"

  dkrup old
fi
finish
