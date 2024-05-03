#!/usr/bin/env bash

source .common.bash

lock check && die "В данный момент работает другая копия данного скрипта" \
  "(либо она неожиданно завершилась и не успела снять блокировку." \
  "Если это так - удалите файл ${lockfile} вручную)"
already_run 'bash update.bash' && die "В данный момент работает старая версия данного скрипта." \
  "Запустимся в следующий раз."

lock do

if [[ -d "${PWD}/.git" ]]; then
  checkutil git || die "Не удалось найти утилиту 'git' (она нужна для скачивания обновлений)"
  checkutil sed || die "Не удалось найти утилиту 'sed'"

  released_verion=$(released_version)
  current_tag=$(current_tag)

  if ! (is_detached && is_on_tag); then
    current_version=0.0.0
  else
    current_version="${current_tag##v}"
  fi
  if ver_lt "${current_version##v}" "${released_verion##v}"; then
    git fetch --quiet --tags --force --prune --prune-tags &>/dev/null
    # TODO: ☝️ проверить что все из этих опций совместимы со старьём типа 1.8.3.1 (Centos7?)

    if git checkout --quiet --force "${released_verion}"; then
      lock undo
      bash start.bash
    else
      die "Не получилось обновить слепок кода. Пожалуйста, обратитесь в чат!"
    fi
  fi
  lock undo
else
  lock undo
  echo "Кажется, Вы установили данное ПО не по инструкции (скачав git-репозиторий), а из архива"
  echo "Работоспособность обновления при данном способе не гарантируется, но, всё же, попробуем обновить"

  bash install.bash
fi
