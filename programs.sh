#!/usr/bin/env bash

set -e

# Делаем скрипт исполняемым
chmod +x "$0"

# Определяем, какое окружение рабочего стола используется
TERMINAL=""
if [[ -n "$KDE_FULL_SESSION" ]]; then
    TERMINAL="konsole -e"
elif [[ -n "$GNOME_DESKTOP_SESSION_ID" ]]; then
    TERMINAL="gnome-terminal --"
elif [[ "$XDG_CURRENT_DESKTOP" == *"XFCE"* ]]; then
    TERMINAL="xfce4-terminal -e"
elif [[ "$XDG_CURRENT_DESKTOP" == *"Cinnamon"* ]]; then
    TERMINAL="x-terminal-emulator -e"
elif [[ "$XDG_CURRENT_DESKTOP" == *"MATE"* ]]; then
    TERMINAL="mate-terminal -e"
fi

# Если терминал найден, запустить скрипт в новом окне терминала
if [[ -n "$TERMINAL" && -z "$TERMINAL_STARTED" ]]; then
    export TERMINAL_STARTED=1
    $TERMINAL "$0"
    exit 0
fi

# Список программ для установки (без Docker)
PACKAGES=(
    nodejs npm ark unrar fish openssh haruna neofetch screenfetch qbittorrent telegram-desktop audacity kate vim gimp btrfs-progs gnome-disk-utility
)

# Спрашиваем, нужен ли Docker
read -p "Установить Docker? (y/n): " INSTALL_DOCKER

# Если да, добавляем Docker в список пакетов
if [[ "$INSTALL_DOCKER" == "y" ]]; then
    PACKAGES+=("docker")
fi

# Проверяем, есть ли доступные обновления
if pacman -Qu | grep -q .; then
    sudo pacman -Syy
    sudo pacman -Syu --noconfirm
fi

# Флаг, указывающий, что нужно перезагрузить систему
REBOOT_NEEDED=false

# Проверка и установка пакетов
for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        sudo pacman -S --noconfirm --needed "$pkg"

        # Если устанавливается Fish, потребуется перезагрузка
        if [[ "$pkg" == "fish" ]]; then
            REBOOT_NEEDED=true
        fi
    fi
done

# Настройка Docker, если он был установлен
if [[ "$INSTALL_DOCKER" == "y" ]]; then
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    sudo usermod -aG docker $USER
    REBOOT_NEEDED=true
fi

# Включение OpenSSH
sudo systemctl enable sshd.service
sudo systemctl start sshd.service

# Установка Fish в качестве основного shell
if command -v fish &>/dev/null; then
    if [[ "$(getent passwd $USER | cut -d: -f7)" != "/usr/bin/fish" ]]; then
        sudo chsh -s /usr/bin/fish "$USER"
        echo "Fish установлен и выбран в качестве основного shell."
        REBOOT_NEEDED=true
    fi
else
    echo "Ошибка: Fish не был установлен."
fi

echo "Все программы установлены."

# Перезагрузка, если требуется (только если был установлен Docker или Fish)
if $REBOOT_NEEDED; then
    echo "Перезагрузка системы через 5 секунд..."
    sleep 5
    sudo reboot
else
    echo "Перезагрузка не требуется."
fi
