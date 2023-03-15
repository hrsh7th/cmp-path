# cmp-path

nvim-cmp source for filesystem paths.

# Setup

```lua
require'cmp'.setup {
  sources = {
    { name = 'path' }
  }
}
```


## Configuration

The below source configuration options are available. To set any of these options, do:

```lua
cmp.setup({
  sources = {
    {
      name = 'path',
      option = {
        -- Options go into this table
      },
    },
  },
})
```


### trailing_slash (type: boolean)

_Default:_ `false`

Specify if completed directory names should include a trailing slash. Enabling this option makes this source behave like Vim's built-in path completion.

### label_trailing_slash (type: boolean)

_Default:_ `true`

Specify if directory names in the completion menu should include a trailing slash.

### get_cwd (type: function)

_Default:_ returns the current working directory of the current buffer

Specifies the base directory for relative paths.

### max_traverse_entries (type: number)

_Default:_ `nil`

The maximum count of entries in a directory will this source traverse before returning candidates.

Some directories may have a large number of entries. Users, who prefer to have a time-bounded feedback over completeness, may limit the number of entries this plugin fetches with this option.

If this option is set to nil, there's no effective limit.
