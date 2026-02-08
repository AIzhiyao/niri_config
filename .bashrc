#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
. "$HOME/.cargo/env"


#alias clear='printf "\e[H\e[3J"'
clear() {
    # kitty / 现代终端：真清屏
    if [[ -n "$KITTY_WINDOW_ID" ]]; then
        printf '\033[H\033[3J'
        return
    fi

    # 兜底
    command clear
}
