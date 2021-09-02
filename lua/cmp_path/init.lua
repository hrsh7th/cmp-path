local cmp = require'cmp'

local NAME_REGEX = [[\%([^/\\:\*?<>'"`\|]\)]]
local PATH_REGEX = ([[\%(/PAT\+\)*\ze/PAT*]]):gsub('PAT', NAME_REGEX)

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { '/', '.' }
end

source.get_keyword_pattern = function()
  return '/' .. NAME_REGEX .. '*'
end

source.complete = function(self, request, callback)
  local dirname = self:_dirname(request)
  if not dirname then
    return callback()
  end

  local stat = self:_stat(dirname)
  if not stat then
    return callback()
  end

  self:_candidates(request.context, dirname, request.offset, function(err, candidates)
    if err then
      return callback()
    end
    callback(candidates)
  end)
end

source._dirname = function(self, request)
  local s = vim.regex(PATH_REGEX):match_str(request.context.cursor_before_line)
  if not s then
    return nil
  end

  local dirname = string.sub(request.context.cursor_before_line, s + 2) -- exclude '/'
  local prefix = string.sub(request.context.cursor_before_line, 1, s + 1) -- include '/'

  local buf_dirname = vim.fn.expand(('#%d:p:h'):format(request.context.bufnr))
  if prefix:match('%.%./$') then
    return vim.fn.resolve(buf_dirname .. '/../' .. dirname)
  elseif prefix:match('%./$') then
    return vim.fn.resolve(buf_dirname .. '/' .. dirname)
  elseif prefix:match('~/$') then
    return vim.fn.expand('~/' .. dirname), request.offset
  elseif prefix:match('%$[%a_]+/$') then
    return vim.fn.expand(prefix:match('%$[%a_]+/$') .. dirname)
  elseif prefix:match('/$') then
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

source._stat = function(_, path)
  local stat = vim.loop.fs_stat(path)
  if stat then
    return stat
  end
  return nil
end

local function lines_from(file, count)
  lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
    if count ~= nil and #lines >= count then
	    break
    end
  end
  return lines
end

local function try_get_lines(file, count)
	status, ret = pcall(lines_from, file, count)
	if status then
		return ret
	else
		return nil
	end
end

source._candidates = function(_, context, dirname, offset, callback)
  local fs, err = vim.loop.fs_scandir(dirname)
  if err then
    return callback(err, nil)
  end

  local items = {}


  local include_hidden = string.sub(context.cursor_before_line, offset + 1, offset + 1) == '.'
  while true do
    local name, type, e = vim.loop.fs_scandir_next(fs)
    if e then
      return callback(type, nil)
    end
    if not name then
      break
    end

    local accept = false
    accept = accept or include_hidden
    accept = accept or name:sub(1, 1) ~= '.'

    -- Create items
    if accept then
      if type == 'directory' then
        table.insert(items, {
          word = '/' .. name,
          label = '/' .. name,
          insertText = '/' .. name .. '/',
          kind = cmp.lsp.CompletionItemKind.Folder,
        })
      elseif type == 'link' then
        local stat = vim.loop.fs_stat(dirname .. '/' .. name)
        if stat then
          if stat.type == 'directory' then
            table.insert(items, {
              word = '/' .. name,
              label = '/' .. name,
              insertText = '/' .. name .. '/',
              kind = cmp.lsp.CompletionItemKind.Folder,
            })
          else
            table.insert(items, {
              label = name,
              filterText = '/' .. name,
              insertText = '/' .. name,
              kind = cmp.lsp.CompletionItemKind.File,
	      path = dirname .. '/' .. name,
            })
          end
        end
      elseif type == 'file' then
        table.insert(items, {
          label = name,
          filterText = '/' .. name,
          insertText = '/' .. name,
          kind = cmp.lsp.CompletionItemKind.File,
	  path = dirname .. '/' .. name,
        })
      end
    end
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
  if completion_item.kind == cmp.lsp.CompletionItemKind.File then
	completion_item.documentation = try_get_lines(completion_item.path, 10)
  end
  callback(completion_item)
end

return source

