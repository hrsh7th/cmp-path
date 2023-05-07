if vim.g.loaded_cmp_path then
    return
end
vim.g.loaded_cmp_path = true

require('cmp').register_source('path', require('cmp_path').new())
