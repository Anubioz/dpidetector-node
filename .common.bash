cd $(dirname $0)

### Variables {{{
REPO_URL="https://github.com/DPIdetector/dpidetector-node"
CDIR="${PWD}/.cache"
CFG="${CDIR}/config"
### /Variables }}}

### Functions {{{

function die() {
  echo "${*}" >&2
  lock undo
  [[ -n "${nonfatal}" ]] || exit 1
}

function nonfatal() {
  nonfatal=1 ${*}
}

function checkutil() {
  which "${1}" &>/dev/null
}

function co() {
  checkutil git || die "Не удалось найти утилиту 'git'"
  git clone "${REPO_URL}" "${1}"
}

function is_writeable() {
  if touch "${1}/.tst" &>/dev/null; then
    rm "${1}/.tst" &>/dev/null
    return 0
  else
    return 1
  fi
}

function setup() {
  checkutil sed  || die "Не удалось найти утилиту 'sed'"
  mkdir -p "${CDIR}" &>/dev/null ||
    die "Невозможно создать директорию для хранения настроек и временных файлов (${CDIR})"
  if is_writeable /run;  then
    export LOCKDIR=/run
  elif is_writeable /tmp;  then
    export LOCKDIR=/tmp
  elif is_writeable "${CDIR}";  then
    export LOCKDIR="${CDIR}"
  else
    die "Нет доступа на запись даже в рабочую директорию проекта (${PWD}). Обновление невозможно."
  fi
  if [[ -f "${CFG}" ]]; then
    sed -e '/LOCKDIR/d' -i "${CFG}"
  else
    touch "${CFG}"
  fi
  echo "LOCKDIR='${LOCKDIR}'" >> "${CFG}"
}

function lock() {
  is_writeable "${LOCKDIR}" || die "Нет доступа к директории ${LOCKDIR}." \
  "Возможно, что-то не так с настройками безопасности или с Вашей файловой системой." \
  "На всякий случай, попробуйте удалить файл ${CFG} и перезапустить этот скрипт"

  export lockfile="${LOCKDIR}/dpidetector-update.lock"

  case "${1}" in
    check)
      [[ -f "${lockfile}" ]]
      ;;
    do)
      [[ -f "${lockfile}" ]] ||
      touch "${lockfile}"
      ;;
    undo)
      [[ -f "${lockfile}" ]] &&
      rm -f "${lockfile}"
      ;;
  esac
}

function already_run() {
  checkutil pgrep || die "Не удалось найти 'pgrep'"
  local what="${1:-${0}}"
  [[ $(pgrep -f "${what}" | wc -l) -gt 1 ]]
}

function ver_min() {
  checkutil head || die "Не удалось найти утилиту 'head'"
  checkutil sort || die "Не удалось найти утилиту 'sort'"
  echo 1.1.1 | sort -V &>/dev/null || die "Не поддерживаемая (устаревшая?) версия sort"
  sort -V | head -n 1
}

function ver_max() {
  checkutil head || die "Не удалось найти утилиту 'head'"
  checkutil sort || die "Не удалось найти утилиту 'sort'"
  echo 1.1.1 | sort -V &>/dev/null || die "Не поддерживаемая (устаревшая?) версия sort"
  sort -V --reverse | head -n 1
}

function ver_lte() {
  local lesser=$(echo -e "$1\n$2" | ver_min)
  [[ "$1" == "${lesser}" ]]
}

function ver_lt() {
  if [[ "${1}" == "${2}" ]]; then
    return 1
  else
    ver_lte "${1}" "${2}"
  fi
}

function check_tag_on_ghcr() {
  checkutil curl || die "Не удалось найти 'curl'"
  checkutil sed  || die "Не удалось найти утилиту 'sed'"
  checkutil grep || die "Не удалось найти утилиту 'grep'"
  local token=$(curl -Lsf "https://ghcr.io/token?scope=repository:${1}:pull 2>/dev/null" | sed -e 's@.*"token":"\([^"]*\)".*$@\1@')
  if [[ -n "${token}" ]]; then
    curl \
      -H "Authorization: Bearer ${token}" \
      -Lsf "https://ghcr.io/v2/${1}/manifests/${2:-latest}" 2>/dev/null | grep -q "digest"
    return $?
  else
    return 1
  fi
}

function check_tag_on_dockerhub() {
  checkutil curl || die "Не удалось найти 'curl'"
  checkutil grep || die "Не удалось найти утилиту 'grep'"
  curl -Lsf "https://hub.docker.com/v2/repositories/${1}/tags/${2:-latest}" 2>/dev/null | grep -q "active"
}

function released_version() {
  checkutil curl || die "Не удалось найти 'curl'"
  curl -Lsf "https://dpidetector.github.io/dpidetector-node/VERSION" || die "Не удалось получить актуальную версию"
}

function current_branch() {
  checkutil git || die "Не удалось найти утилиту 'git'"
  git branch | grep '^\*'
}

function current_tag() {
  checkutil git || die "Не удалось найти утилиту 'git'"
  local at_ref=$(git describe --tags --always)
  [[ "${at_ref}" =~ ^v[0-9]*\.[0-9]*\.[0-9]*$ ]] && echo -n "${at_ref}"
}

function is_on_tag() {
  [[ -n "$(current_tag)" ]]
}

function is_detached() {
  # checkutil git || die "Не удалось найти утилиту 'git'"
  # [[ HEAD == $(git rev-parse --abbrev-ref --symbolic-full-name HEAD) ]]
  [[ -z $(current_branch | grep -q detached) ]]
}

### /Functions }}}

if [[ -f "${CFG}" ]]; then
  source "${CFG}"
else
  setup
fi
