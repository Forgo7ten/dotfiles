# 变量定义
adb_exe="adb"
alias open_lsposed="adb shell am start -n com.android.shell/.BugreportWarningActivity -c org.lsposed.manager.LAUNCH_MANAGER"

_get_all_adb_devices() {
    # 使用 awk 直接提取状态为 device 的序列号
    $adb_exe devices | tr -d '\r' | awk 'NR>1 && $2=="device" {print $1}'
}
# 内部函数：选择设备
# 成功：echo 设备ID到 stdout, return 0
# 失败：echo 错误信息到 stderr, return 1
_select_adb_device() {
    local devices=($(_get_all_adb_devices))
    local count=${#devices[@]}

    if [ ${count} -eq 0 ]; then
        echo -e "Error: No adb devices found." >&2
        return 1
    elif [ ${count} -eq 1 ]; then
        # 只有一个设备时直接输出
        [ -n "$ZSH_VERSION" ] && echo "${devices[1]}" || echo "${devices[0]}" # 兼容处理：Zsh 取 [1]，Bash 取 [0]
        return 0
    else
        local PS3="Please select a num for adb device: "
        local opt
        select opt in "${devices[@]}"; do
            if [ -n "$opt" ]; then
                echo "$opt"
                return 0
            else
                echo -e "Invalid selection, try again." >&2
            fi
        done
    fi
}

## 提取设备中安装的所有apk文件到out目录中
# @param out 输出目录
aplapks(){
    local selected_device
    selected_device=$(_select_adb_device) || return 1

    local output_dir="${1%/}"
    if [ -z "$output_dir" ]; then
        echo -e "Usage: aplapks <output_directory>"
        return 1
    fi

    mkdir -p "$output_dir"
    echo -e "Fetching package list from $selected_device..."

    local pkg_data
    pkg_data=$($adb_exe -s "$selected_device" shell "pm list packages -f" | tr -d '\r' | sed 's/^package://' | grep -v "/overlay/")

    local total=$(echo "$pkg_data" | grep -c "=")
    local current=0

    echo "Total packages: $total. Starting pull..."

    while read -r line; do
        [ -z "$line" ] && continue
        
        # 路径在最后一个 = 之前，包名在最后一个 = 之后
        local package_name="${line##*=}"
        local package_path="${line%=*}"
        
        ((current++))

        # 采用对齐输出，看起来更整齐
        printf "[%3d/%3d] Pulling: %-50s " "$current" "$total" "$package_name"
        
        if $adb_exe -s "$selected_device" pull "$package_path" "$output_dir/${package_name}.apk" &> /dev/null; then
            echo -e "\033[32m[OK]\033[0m"
        else
            echo -e "\033[31m[FAILED]\033[0m"
        fi
    done <<< "$pkg_data"
    
    echo -e "\n\033[32mFinished. All APKs saved to: $output_dir\033[0m"
}
fregister "aplapks" "提取设备中安装的所有apk文件到指定目录中"


## 提取匹配关键字的apk文件到当前目录下
# @param pkg 要提取的apk文件包名
aplapk() {
    local selected_device
    selected_device=$(_select_adb_device) || return 1

    local pkg_filter="$1"
    if [ -z "$pkg_filter" ]; then
        echo "Usage: aplapk <package_filter>"
        return 1
    fi

    local pkg_data
    pkg_data=$($adb_exe -s "$selected_device" shell "pm list packages -f" | tr -d '\r' | sed 's/^package://' | grep -i "$pkg_filter")

    if [ -z "$pkg_data" ]; then
        echo -e "No packages found matching '$pkg_filter'."
        return 1
    fi

    echo "$pkg_data" | while read -r line; do
        local package_name="${line##*=}"
        local package_path="${line%=*}"
        echo -n "Pulling $package_name... "
        $adb_exe -s "$selected_device" pull "$package_path" "./${package_name}.apk" &> /dev/null && echo "OK" || echo "Failed"
    done
    echo "Done."
}
fregister "aplapk" "提取匹配关键字的apk文件到当前目录下"

## 获取 UID
apuid(){
    local selected_device
    selected_device=$(_select_adb_device) || return 1

    local pkg="$1"
    if [ -z "$pkg" ]; then
        $adb_exe -s "$selected_device" shell "pm list packages -U" | tr -d '\r'
    else
        $adb_exe -s "$selected_device" shell "pm list packages -U" | tr -d '\r' | grep -i "$pkg"
    fi
}
alias apuids="apuid"
fregister "apuid/apuids" "获取设备中安装的所有(指定)应用的 UID"

## 打开指定包名的应用详情页 (App Info)
# @param pkg 包名 (支持模糊搜索，如果匹配到多个会提示)
apinfo() {
    local selected_device
    selected_device=$(_select_adb_device) || return 1

    local pkg_filter="$1"
    if [ -z "$pkg_filter" ]; then
        echo "Usage: apinfo <package_name_or_filter>"
        return 1
    fi

    # 尝试查找匹配的包名
    local pkg_list
    pkg_list=$($adb_exe -s "$selected_device" shell "pm list packages" | tr -d '\r' | sed 's/^package://' | grep -i "$pkg_filter")

    local count=$(echo "$pkg_list" | grep -c .)

    if [ "$count" -eq 0 ]; then
        echo -e "\033[31mError: No package found matching '$pkg_filter'\033[0m"
        return 1
    elif [ "$count" -gt 1 ]; then
        echo "Multiple packages found. Please be more specific:"
        echo "$pkg_list"
        return 1
    fi

    # 只有一个匹配项时执行
    local target_pkg=$(echo "$pkg_list" | xargs)
    echo "Opening info for: $target_pkg"
    $adb_exe -s "$selected_device" shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:"$target_pkg" > /dev/null
}
fregister "apinfo" "打开指定包名的设置 应用详情页"

