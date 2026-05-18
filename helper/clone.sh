#!/usr/bin/env bash

REPOSITORY_LINKS=(
  https://github.com/robbyrussell/oh-my-zsh
  https://github.com/zsh-users/zsh-syntax-highlighting
  https://github.com/zsh-users/zsh-autosuggestions
  https://github.com/joshskidmore/zsh-fzf-history-search
  https://github.com/marlonrichert/zsh-autocomplete
  https://github.com/jimeh/tmux-themepack
  https://github.com/NvChad/starter
)

REPOSITORY_APIS=(
  repositories/291137
  repos/zsh-users/zsh-syntax-highlighting
  repos/zsh-users/zsh-autosuggestions
  repos/joshskidmore/zsh-fzf-history-search
  repos/marlonrichert/zsh-autocomplete
  repos/jimeh/tmux-themepack
  repos/NvChad/starter
)

REPOSITORY_FULL_NAME=(
  robbyrussell/oh-my-zsh
  zsh-users/zsh-syntax-highlighting
  zsh-users/zsh-autosuggestions
  joshskidmore/zsh-fzf-history-search
  marlonrichert/zsh-autocomplete
  jimeh/tmux-themepack
  NvChad/starter
)

REPOSITORY_PATH=(
  $HOME/.oh-my-zsh/
  $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
  $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
  $HOME/.oh-my-zsh/custom/plugins/zsh-fzf-history-search
  $HOME/.oh-my-zsh/custom/plugins/zsh-autocomplete
  $HOME/.tmux-themepack
  $HOME/NvChad
)

function repoSize() {

    local size_kb=$(curl -s "https://api.github.com/$@" | grep '"size":' | head -1 | tr -dc '[:digit:]')
    if [[ -z "$size_kb" ]]; then
        echo "0.00MB"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $size_kb / 1024}")MB"
    fi

}

function repositories() {

  setCursor off

  echo -e "‏‏‎‏‏‎ ‎ ‎‏‏‎  ‎📦 Getting Information Repository"
  sleep 2s

  echo -e "
    ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
    ┃                         Information Repository                     ┃ 
    ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
    ┃      Repository Name                          Repository Size      ┃
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

  for REPOSITORY_API in "${REPOSITORY_APIS[@]}"; do

    REPOSITORY_NAME=$(curl https://api.github.com/${REPOSITORY_API} 2> /dev/null | grep full_name | sed -n 1p | awk '{print $2}' | sed "s/,//g" | sed "s/\"//g")
    printf  "    ┃      ${COLOR_SUCCESS}%-36s${COLOR_BASED}       ${COLOR_WARNING}%8s${COLOR_BASED}           ┃\n" $REPOSITORY_NAME `repoSize $REPOSITORY_API`
    echo -e "    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"

  done

  echo -e ""

}

function cloneRepository() {

  setCursor off

  echo -e "\n‏‏‎‏‏‎ ‎ ‎‏‏‎  ‎📦 Clone or Downloading Repository\n"  
  sleep 2s

  for ((i=0; i<${#REPOSITORY_LINKS[@]}; i++)); do

    start_animation "       Cloning ${COLOR_WARNING}'${COLOR_SUCCESS}${REPOSITORY_FULL_NAME[i]}${COLOR_WARNING}'${COLOR_BASED} ..."

    git clone ${REPOSITORY_LINKS[i]} ${REPOSITORY_PATH[i]} 2> /dev/null

    if [ -d ${REPOSITORY_PATH[i]} ]; then

      stop_animation $? || exit 1

    else

      stop_animation $?

    fi

  done

  setCursor on

}
