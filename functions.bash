info() {
    [ "${ENABLE_INFO}" == "1" ] && echo $*
}


progress() {
    [ "${ENABLE_PROGRESS}" == "1" ] && echo $*
}
