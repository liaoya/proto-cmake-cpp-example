#!/bin/bash

set -e

THIS_FILE=$(readlink -f "${BASH_SOURCE[0]}")
THIS_DIR=$(dirname "${THIS_FILE}")
#shellcheck disable=SC1091
source "${THIS_DIR}/proxy.sh"

function _check_command() {
    while (($#)); do
        if ! command -v "${1}" 1>/dev/null 2>&1; then
            echo "Command ${1} is required"
            return 1
        fi
        shift
    done
    return 0
}

_tmp_dir=$(mktemp -d)
declare -r _tmp_dir
# shellcheck disable=SC2064
trap \
    "{ sudo rm -fr ${_tmp_dir}; }" \
    SIGINT ERR EXIT
_tmp_build_dir=${_tmp_dir}/build

if [[ $# -gt 0 ]] && [[ $1 == "-l" || $1 == "list" ]]; then
    grep -e "^function _install_" "${THIS_FILE}" | sed -e 's/function _install_//g' -e 's/() {//g' | grep -v _cmake_module | sort
    exit 0
fi

if [[ $# -gt 0 ]] && [[ $1 == "-h" || $1 == "--help" || $1 == "help" ]]; then
    #shellcheck disable=SC2086
    echo "$(basename ${THIS_FILE}) -c [-h] [-l] program ..."
    exit 0
fi

if ! _check_command cmake gcc g++ make ninja; then
    sudo apt-get update -qy
    sudo apt-get install -qy --no-install-recommends build-essential cmake ninja-build
fi
if command -v ninja 1>/dev/null 2>&1; then
    export CMAKE_GENERATOR=Ninja
fi

#shellcheck disable=SC2154
function _install_cmake_module() {
    local _cmake_opts _download_url _name
    local _param
    if [[ $# -lt 1 ]]; then
        echo "Please provide a prameter"
    fi
    eval "declare -A _params=${1#*=}"
    IFS=" " read -r -a _cmake_opts <<< "${_params[cmake_opts]}"
    _download_url=${_params[download_url]}
    _name=${_params[name]}
    if [[ -z ${_name} || -z  ${_download_url} ]]; then
        echo "Both name and download_url must be provided"
        return
    fi

    sudo rm -fr "${_tmp_build_dir}" || true
    mkdir -p "${_tmp_dir}/${_name}"
    # https://stackoverflow.com/questions/19858600/accessing-last-x-characters-of-a-string-in-bash
    if [[ ${_download_url:(-3)} == .gz ]]; then
        curl -sL -o - "${_download_url}" | tar --strip-components=1 -zxf - -C "${_tmp_dir}/${_name}"
    elif [[ ${_download_url:(-4)} == .bz2 ]]; then
        curl -sL -o - "${_download_url}" | tar --strip-components=1 -jxf - -C "${_tmp_dir}/${_name}"
    elif [[ ${_download_url:(-3)} == .xz ]]; then
        curl -sL -o - "${_download_url}" | tar --strip-components=1 -Jxf - -C "${_tmp_dir}/${_name}"
    fi
    if [[ -n ${_params[pre_cmds]} ]]; then
        eval "${_params[pre_cmds]}"
    fi
    cmake -S "${_tmp_dir}/${_name}" -B "${_tmp_build_dir}" "${_cmake_opts[@]}"
    cmake --build "${_tmp_build_dir}"
    sudo cmake --build "${_tmp_build_dir}" --target install/strip
    if [[ -n ${_params[post_cmds]} ]]; then
        eval "${_params[post_cmds]}"
    fi
}

#shellcheck disable=SC2154
function _install_github_cmake_module() {
    local _download_url _global_version_name _name _version _version_url
    local _param
    if [[ $# -lt 1 ]]; then
        echo "Please provide a prameter"
    fi
    eval "declare -A _params=${1#*=}"
    _download_url=${_params[download_url]}
    _name=${_params[name]}
    _version=${_params[version]}
    _version_url=${_params[version_url]}
    if [[ -z ${_name} || -z  ${_download_url} ]]; then
        echo "Both name and download_url must be provided"
        return
    fi
    eval "_global_version_name=${_name^^}_VERSION"
    if [[ -z ${!_global_version_name} ]]; then
        if [[ -z ${_version} && -z ${_version_url} ]]; then
            _version_url=https://api.github.com/repos/$(echo "${_download_url}" | cut -d/ -f4,5)/releases/latest
        fi
        if [[ -z ${_version} && -n ${_version_url} ]]; then
            _version=$(curl -sL "${CURL_OPTS[@]}" "${_version_url}" | jq -r .tag_name)
        fi
        eval "${_global_version_name}=${_version}"
    fi
    eval "_params[download_url]=${_download_url}"

    _install_cmake_module "$(declare -p _params)"
}

function _install_abseil_cpp() {
    local _params
    #shellcheck disable=SC2016
    declare -A _params=([name]=abseil_cpp
        [download_url]='https://github.com/abseil/abseil-cpp/releases/download/${ABSEIL_CPP_VERSION}/abseil-cpp-${ABSEIL_CPP_VERSION}.tar.gz'
        [version]=20240722.0
        [version_url]=https://api.github.com/repos/abseil/abseil-cpp/releases/latest
        [cmake_opts]="-DABSL_PROPAGATE_CXX_STD=ON"
    )
    _install_github_cmake_module "$(declare -p _params)"
}

function _remove_abseil() {
    sudo rm -fr /usr/local/include/absl/
    sudo rm -fr /usr/local/lib/cmake/absl/
    sudo rm -fr /usr/local/lib/libabsl_*
    sudo rm -fr /usr/local/lib/pkgconfig/absl_*.pc
}

function _install_protobuf() {
    local _params
    #shellcheck disable=SC2016
    declare -A _params=([name]=protobuf
        [download_url]='https://github.com/protocolbuffers/protobuf/archive/refs/tags/${PROTOBUF_VERSION}.tar.gz'
        [version]=v27.3
        [version_url]=https://api.github.com/repos/protocolbuffers/protobuf/releases/latest
        [cmake_opts]="-Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_ABSL_PROVIDER=package"
    )
    _install_github_cmake_module "$(declare -p _params)"
}

function _remove_protobuf() {
    sudo rm -fr /usr/local/include/utf8_range.h
    sudo rm -fr /usr/local/include/utf8_validity.h
    sudo rm -fr /usr/local/lib/cmake/utf8_range/
    sudo rm -fr /usr/local/lib/libutf8_range.a
    sudo rm -fr /usr/local/lib/libutf8_validity.a

    sudo rm -fr /usr/local/include/upb_generator/mangle.h
    sudo rm -fr /usr/local/include/upb/
    sudo rm -fr /usr/local/lib/libupb.a

    sudo rm -fr /usr/local/bin/protoc*
    sudo rm -fr /usr/local/include/google/protobuf/
    sudo rm -fr /usr/local/include/java/core/src/main/resources/google/protobuf/java_features.proto
    sudo rm -fr /usr/local/lib/cmake/protobuf/
    sudo rm -fr /usr/local/lib/libprotobuf*.a
    sudo rm -fr /usr/local/lib/pkgconfig/protobuf*.pc
}

function _install_all() {
    grep -e '^function _remove_[[:alnum:]]*' "${THIS_FILE}" | sed "s/() {//g" | sed "s/function //g" | sort | while IFS= read -r remove_func; do
        "${remove_func}"
    done
    grep -e '^function _install_[[:alnum:]]*' "${THIS_FILE}" | sed "s/() {//g" | sed "s/function //g" | grep -v "_install_all" | grep -v "_install_github_cmake_module" | sort | while IFS= read -r install_func; do
        "${install_func}"
    done
}

while (($#)); do
    name=${1//-/_}
    shift
    if grep -s -q -e "^function _install_${name}()" "${THIS_FILE}"; then
        if grep -s -q -e "^function _remove_${name}()" "${THIS_FILE}"; then
            "_remove_${name}"
        fi
        "_install_${name}"
    else
        echo "Can't find '_install_${name}' in '${THIS_FILE}'"
        exit 1
    fi
done

