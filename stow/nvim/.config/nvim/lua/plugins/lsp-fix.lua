return {
  -- Add mason.nvim first
  {
    "williamboman/mason.nvim",
    lazy = false,
    priority = 1001,
    opts = {},
  },
  -- Then add mason-lspconfig with proper dependencies
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    priority = 1000,
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = {
        "lua_ls",
      },
    },
  },
  -- Make LSP wait for mason-lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
    },
    event = "VeryLazy", -- Load later
  },
}
