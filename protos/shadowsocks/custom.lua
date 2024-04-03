local sp      = require"subprocess"
local req     = require"checker.requests"
local json    = require"cjson"
local utils   = require"checker.utils"
local sleep   = utils.sleep
local wait    = utils.wait
local log     = utils.logger
local getconf = utils.getconf

local _C = {}

_C.proto = "shadowsocks"

_C.connect = function(server)
  log.debug"==== Вход в функцию подключения ===="
  log.print"Подключение..."
  log.debug(("(сервер: %s)"):format(server.domain))

  log.debug"===== Получение параметров подключения к серверу ====="
  local meta_r = req{
    url = ("https://%s:%d/%s"):format(server.domain, server.port, _C.proto),
    headers = _G.headers,
  }
  log.debug"===== Завершено ====="

  log.debug"===== Попытка десериализации полученного конфига ====="
  if meta_r:match"^%[" or meta_r:match"^%{" then
      local ok, res = pcall(json.decode, meta_r)
    if ok then
      server.meta = res
    else
      log.bad(("Ошибка десериализации мета-информации о сервере: %s"):format(meta_r))
      return false
    end
  end
  log.debug"===== Завершено ====="

  local _E = {}

  log.debug"===== Выполнение команды подключения ====="
  _C.ss_proc, _E.errmsg, _E.errno = sp.popen{
    "/usr/bin/sslocal",
    "-s", ("%s:%d"):format(server.meta.server_ip, server.meta.port),
    "-k", server.meta.password,
    "-b", "127.0.0.1:1080",
    "-m", server.meta.encryption,
    "--timeout", "60",
    stdout = _G.log_fd or _G.stdout,
    stderr = _G.log_fd or _G.stderr,
  }
  if not _C.ss_proc or _C.ss_proc:poll() then
    log.bad(("Проблема при инициализации! Сообщение об ошибке: %s. Код: %d"):format(_E.errmsg, _E.errno))
    if _C.ss_proc then _C.ss_proc:kill() end
    _C.ss_proc = nil
    log.debug"===== перед вызовом wait() ====="
    wait()
    log.debug"===== после вызова wait() ====="
    return false
  end
  log.debug"===== Завершено ====="
  sleep(5)
  log.good"Подключение активировано"
  log.debug"==== Выход из функции подключения ===="
  return true
end

_C.disconnect = function(_server)
  log.debug"==== Вход в функцию завершения подключения ===="
  if _C.ss_proc then
    log.print"Завершение подключения"
    _C.ss_proc:terminate()
    _C.ss_proc:wait()
    _C.ss_proc = nil
    sleep(2)
    log.debug"===== перед вызовом wait() ====="
    wait()
    log.debug"===== после вызова wait() ====="
  else
    log.bad"Вызвана функция отключения, но исчезли дескрипторы подключения. Нужна отладка!"
  end
  log.debug"==== Выход из функции завершения подключения ===="
end

_C.checker = function(server)
  log.debug"==== Вход в функцию проверки доступности ===="
  log.print"Проверка доступности начата"

  local ret = false
  local res = req{
    url = getconf("get_ip_url"),
    proxy = "socks5://127.0.0.1:1080",
  }

  if res:match(server.meta.server_ip) then
    ret = true
    log.good"Проверка завершена успешно"
  else
    log.bad"Проверка провалилась!"
    log.debug(("IP сервера (из метаданных): %q"):format(server.meta.server_ip))
    log.debug(("Ответ сервиса определения IP (или ошибка cURL): %q"):format(res))
    if res:match"^%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?$" then --- TODO: IPv6 когда докер будет уметь его из коробки
      log.debug"%{bold} Учитывая, что выше не ошибка подключения, а два разных IP, скорее всего проявился какой-то баг"
      log.debug"%{bold} Возможные варианты:"
      log.debug"%{bold} - не отключилось предыдущее подключение"
      log.debug"%{bold} - что-то с обновлением конфига (или шаблоном)"
      log.debug"%{bold} - баг в туннелирующем софте и на предыдущей итерации он отказался отключаться"
      log.debug"%{bold} В любом случае - нужно написать в чат"
    end
  end
  log.debug"==== Выход из функции проверки доступности ===="
  return ret
end

return _C
