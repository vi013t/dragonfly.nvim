# `dragonfly.nvim`

A pretty search & replace plugin for Neovim, supporting both single file replacement and project-wide, as well as optionally respecting `.gitignore`.

![demo](./docs/demo.png)

### Installation & Configuration

It's required to [install ripgrep](https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation).

Basic installation expample (with `lazy.nvim`):

```lua
{
    "vi013t/dragonfly.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    keys = {
        { "<C-/>", "<cmd>Dragonfly<cr>" }
    }
}
```

<details>
    <summary>Default Configuration</summary>

```lua
{
    "vi013t/dragonfly.nvim",
    opts = {
        on_open = function() end,
        on_close = function() end,
    },
    keys = {
        { "<C-/>", "<cmd>Dragonfly<cr>" }
    }
}
```
</details>

<details>
    <summary>Example for replacing Neo-Tree (like in demo above)</summary>

```lua
{
    "vi013t/dragonfly.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
        on_open = function()
            if vim.fn.exists(":NeoTreeClose") then vim.cmd("NeoTreeClose") end
        end,
        on_close = function()
            require("neo-tree") -- Load neo-tree in case it isn't yet
            vim.cmd("Neotree")
        end,
    },
    keys = {
        { "<C-/>", "<cmd>Dragonfly<cr>" }
    }
},

```
</details>

<details>
    <summary>Example for `bufferline.nvim` title (like in demo)</summary>

```lua
{
    "akinsho/bufferline.nvim",
    config = function()

        -- Create highlight group
        local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("NormalFloat")), "bg#")
        local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("@type")), "fg#")
        vim.api.nvim_set_hl(0, "BufferlineDragonflyOffset", { bg = bg, fg = fg })

        -- Set up bufferline
        bufferline.setup({
            options = {
                offsets = {
                    {
                        filetype = "dragonfly",
                        text = "󰠭 Dragonfly",
                        highlight = "BufferlineDragonflyOffset"
                    }
                }
            },
        })
    end
}
```

</details>

