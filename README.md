# cmp-path

nvim-cmp source for filesystem paths.

# Setup

```lus
require'cmp'.setup {
  sources = {
    { name = 'path' }
  }
}
```

## Configuration

### trailing_slash (type: boolean)

_Default:_ `false`

Specify if completed directory names should include a trailing slash. Enabling this option makes this source behave like Vim's built-in path completion.

### label_trailing_slash (type: boolean)

_Default:_ `true`

Specify if directory names in the completion menu should include a trailing slash.

### get_cwd (type: function)

_Default:_ returns the current working directory of the current buffer

Specifies the base directory for relative paths.

### path_mappings (type: table<string, string>)

_Default:_ `{}`

Defines custom path aliases.

Key: The abbreviated path. After triggering the path completion, the path will be completed as if it had been expanded.

Value: The expanded path. `${folder}` will be expanded to the CWD.

Example:

```lua
{
  name = 'path',
  option = {
    path_mappings = {
        ['@'] = '${folder}/src',
        -- ['/'] = '${folder}/src/public/',
        -- ['~@'] = '${folder}/src',
        -- ['/images'] = '${folder}/src/images',
        -- ['/components'] = '${folder}/src/components',
    },
  }
}
```
