# Ryoku palette for fish and fzf. Rendered by the theme daemon; do not edit.
#
# Dropped straight into conf.d, which fish sources on its own, so nothing in the
# shipped config has to include it. Your ~/.config/fish/user.fish loads last and
# still wins.

# Syntax highlighting.
set -g fish_color_normal e0e3e8
set -g fish_color_command 98ccf9
set -g fish_color_keyword d1bfe7
set -g fish_color_quote b8c8d9
set -g fish_color_redirection c2c7ce
set -g fish_color_end d1bfe7
set -g fish_color_error ffb4ab
set -g fish_color_param e0e3e8
set -g fish_color_comment 8c9198
set -g fish_color_selection --background=034b71
set -g fish_color_operator d1bfe7
set -g fish_color_escape b8c8d9
set -g fish_color_autosuggestion 8c9198
set -g fish_color_cancel ffb4ab
set -g fish_color_search_match --background=034b71
set -g fish_color_valid_path --underline

# Completion pager.
set -g fish_pager_color_progress c2c7ce
set -g fish_pager_color_prefix 98ccf9
set -g fish_pager_color_completion e0e3e8
set -g fish_pager_color_description 8c9198
set -g fish_pager_color_selected_background --background=034b71

# fzf takes the same palette, so Ctrl-R and Ctrl-T match the terminal they open
# in. Appended to whatever options are already set rather than replacing them.
set -gx FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS \
--color=fg:#e0e3e8,bg:-1,hl:#98ccf9 \
--color=fg+:#e0e3e8,bg+:#034b71,hl+:#98ccf9 \
--color=info:#b8c8d9,prompt:#98ccf9,pointer:#d1bfe7 \
--color=marker:#d1bfe7,spinner:#b8c8d9,header:#8c9198 \
--color=border:#42474d"
