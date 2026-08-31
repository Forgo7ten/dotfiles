return {
  {
    "saghen/blink.cmp",

    opts = {
      keymap = {
        -- 修改 blink.cmp 的补全确认方式为 Super Tab。
        --
        -- 默认配置通常使用 Enter（<CR>）确认补全；
        -- 改为 super-tab 后，Tab 会根据当前状态自动执行不同操作：
        --   1. 补全菜单打开时：选择并确认当前补全项
        --   2. Snippet 展开后：跳转到下一个占位符
        --   3. 没有补全或 Snippet 时：执行普通 Tab 行为
        --
        -- Shift-Tab 则可在 Snippet 中跳转到上一个占位符。
        preset = "super-tab",
      },
    },
  },
}
