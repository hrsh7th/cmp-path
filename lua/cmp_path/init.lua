local cmp = require'cmp'

local NAME_REGEX = '\\%([^/\\\\:\\*?<>\'"`\\|]\\)'
local PATH_REGEX = vim.regex(([[\%(/PAT\+\)*/\zePAT*$]]):gsub('PAT', NAME_REGEX))

local source = {}

local constants = {
  max_lines = 20,
}


---@class cmp_path.Options
---@field public trailing_slash boolean

---@type cmp_buffer.Options
local defaults = {
  trailing_slash = false,
  get_cwd = function(params)
    return vim.fn.expand(('#%d:p:h'):format(params.context.bufnr))
  end,
}

source.new = function()
  return setmetatable({}, { __index = source })
end

---@return cmp_buffer.Options
source._validate_options = function(_, params)
  local opts = vim.tbl_deep_extend('keep', params.option, defaults)
  vim.validate({
    trailing_slash = { opts.trailing_slash, 'boolean' },
    get_cwd = { opts.get_cwd, 'function' },
  })
  return opts
end

source.get_trigger_characters = function()
  return { '/', '.' }
end

source.get_keyword_pattern = function()
  return NAME_REGEX .. '*'
end

source.complete = function(self, params, callback)
  local opts = self:_validate_options(params)

  local dirname = self:_dirname(params, opts)
  if not dirname then
    return callback()
  end

  local include_hidden = string.sub(params.context.cursor_before_line, params.offset, params.offset) == '.'
  self:_candidates(dirname, include_hidden, opts, function(err, candidates)
    if err then
      return callback()
    end
    callback(candidates)
  end)
end

source._dirname = function(self, params, opts)
  local s = PATH_REGEX:match_str(params.context.cursor_before_line)
  if not s then
    return nil
  end

  local dirname = string.gsub(string.sub(params.context.cursor_before_line, s + 2), '%a*$', '') -- exclude '/'
  local prefix = string.sub(params.context.cursor_before_line, 1, s + 1) -- include '/'

  local buf_dirname = opts.get_cwd(params)
  if vim.api.nvim_get_mode().mode == 'c' then
    buf_dirname = vim.fn.getcwd()
  end
  if prefix:match('%.%./$') then
    return vim.fn.resolve(buf_dirname .. '/../' .. dirname)
  end
  if (prefix:match('%./$') or prefix:match('"$') or prefix:match('\'$')) then
    return vim.fn.resolve(buf_dirname .. '/' .. dirname)
  end
  if prefix:match('~/$') then
    return vim.fn.resolve(vim.fn.expand('~') .. '/' .. dirname)
  end
  local env_var_name = prefix:match('%$([%a_]+)/$')
  if env_var_name then
    local env_var_value = vim.fn.getenv(env_var_name)
    if env_var_value ~= vim.NIL then
      return vim.fn.resolve(env_var_value .. '/' .. dirname)
    end
  end
  if prefix:match('/$') then
    local accept = true
    -- Ignore URL components
    accept = accept and not prefix:match('%a/$')
    -- Ignore URL scheme
    accept = accept and not prefix:match('%a+:/$') and not prefix:match('%a+://$')
    -- Ignore HTML closing tags
    accept = accept and not prefix:match('</$')
    -- Ignore math calculation
    accept = accept and not prefix:match('[%d%)]%s*/$')
    -- Ignore / comment
    accept = accept and (not prefix:match('^[%s/]*$') or not self:_is_slash_comment())
    if accept then
      return vim.fn.resolve('/' .. dirname)
    end
  end
  return nil
end

local function lines_from(file, count)
  local bfile = assert(io.open(file, 'rb'))
  local first_k = bfile:read(1024)
  if first_k:find('\0') then
    return {'binary file'}
  end
  local lines = {'```'}
  for line in first_k:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
    if count ~= nil and #lines >= count then
     break
    end
  end
  lines[#lines + 1] = '```'
  return lines
end

source._candidates = function(_, dirname, include_hidden, opts, callback)
  local fs, err = vim.loop.fs_scandir(dirname)
  if err then
    return callback(err, nil)
  end

  local items = {}

  local function create_item(name, fs_type)
    if not (include_hidden or string.sub(name, 1, 1) ~= '.') then
      return
    end

    local path = dirname .. '/' .. name
    local stat = vim.loop.fs_stat(path)
    local lstat = nil
    if stat then
      fs_type = stat.type
    elseif fs_type == 'link' then
      -- Broken symlink
      lstat = vim.loop.fs_lstat(dirname)
      if not lstat then
        return
      end
    else
      return
    end

    local item = {
      label = name,
      filterText = name,
      insertText = name,
      kind = cmp.lsp.CompletionItemKind.File,
      data = {
        path = path,
        type = fs_type,
        stat = stat,
        lstat = lstat,
      },
    }
    if fs_type == 'directory' then
      item.kind = cmp.lsp.CompletionItemKind.Folder
      item.label = name .. '/'
      item.insertText = name .. '/'
      if not opts.trailing_slash then
        item.word = name
      end
    end
    table.insert(items, item)
  end

  while true do
    local name, fs_type, e = vim.loop.fs_scandir_next(fs)
    if e then
      return callback(fs_type, nil)
    end
    if not name then
      break
    end
    create_item(name, fs_type)
  end

  callback(nil, items)
end

source._is_slash_comment = function(_)
  local commentstring = vim.bo.commentstring or ''
  local no_filetype = vim.bo.filetype == ''
  local is_slash_comment = false
  is_slash_comment = is_slash_comment or commentstring:match('/%*')
  is_slash_comment = is_slash_comment or commentstring:match('//')
  return is_slash_comment and not no_filetype
end

function source:resolve(completion_item, callback)
  local data = completion_item.data
  if data.stat and data.stat.type == 'file' then
    local ok, preview_lines = pcall(lines_from, data.path, constants.max_lines)
    if ok then
      completion_item.documentation = preview_lines
    end
  end
  callback(completion_item)
end

return source
