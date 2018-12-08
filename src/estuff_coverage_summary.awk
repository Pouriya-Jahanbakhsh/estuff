BEGIN {

    FS = "[<>]"

    indent = ""
    pre_name  = "\033[0;34m"
    post_name = "\033[0m"

    pre_low_percentage  = "\033[0;31m"
    post_low_percentage = "\033[0m"

    pre_normal_percentage  = "\033[0;33m"
    post_normal_percentage = "\033[0m"

    pre_high_percentage  = "\033[0;32m"
    post_high_percentage = "\033[0m"

    format = "%s%s%-40s%s%s%-3s%s %s%%%s"

}

$2 == "tr" && ($7 ~ /^{{name}}/ || $7 == "Total") && $13 ~ /%$$/ {
    number = int(substr($13, 1, length($13)-1))
    if (number < 50) {
        pre_percentage  = pre_low_percentage
        post_percentage = post_low_percentage
    } else if (number < 85) {
        pre_percentage  = pre_normal_percentage
        post_percentage = post_normal_percentage
    } else {
        pre_percentage  = pre_high_percentage
        post_percentage = post_high_percentage
    }
    print sprintf(format,
                  indent,
                  pre_name,
                  $7,
                  post_name,
                  pre_percentage,
                  number,
                  post_percentage,
                  pre_name,
                  post_name)
}

$2 == "/table" {
    exit
}
