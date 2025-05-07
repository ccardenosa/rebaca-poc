#!/bin/bash

IMG_TAG='quay.io/ccardenosa/telcov10n-rebaca-poc:stream9'

function load_env {
    source ${PWD}/env.ci
}

function build_image {
    podman build \
        -t ${IMG_TAG} \
        -f Containerfile.rebaca-poc \
        --build-arg user=${C_USER} \
        .
}

function setup_env {

    mkdir -pv \
      ${PWD}/artifacts \
      ${PWD}/shared_dir \
      ${PWD}/vaults \
      ${PWD}/abot-scripts

    # remote_hub_kc_path='rebaca-poc-bastion-10-6-157-20:/var/builds/telco-qe-preserved/ztp-hub-preserved-prod-cluster_profile_dir/hub-kubeconfig'
    # hub_kc_path=${PWD}/artifacts/hub-kubeconfig
    # rsync -avP ${remote_hub_kc_path} ${hub_kc_path}

    for jf in $(ls ${PWD}/vaults/*.json); do
      no_ext_jf=${jf%.json}
      vault_name=$(dirname ${no_ext_jf})/$(basename ${no_ext_jf//./-})
      mkdir -pv ${vault_name}
      # cat $jf | jq -r 'to_entries[] | "\(.key | gsub("/"; "_"))\n\(.value)"' \
      #  | while read -r key; do read -r value; echo "${value}" > "${vault_name}/${key}"; done
      cat $jf | jq -r 'to_entries[] | "\(.key | gsub("/"; "_")) \(.value | @base64)"' \
        | while IFS=' ' read -r key b64value; do
            value=$(echo "$b64value" | base64 -d)
            if [ "${key}" == "ansible_ssh_private_key" ]; then
              echo "${value}" > "${vault_name}/${key}"
            else
              echo -n "${value}" > "${vault_name}/${key}"
            fi
            # echo
            # echo ---- ${key} ---------------------------
            # echo
            # cat ${vault_name}/${key}
            # echo
          done
    done

    #tree ${PWD}/vaults
}


function run_container {
    cmd='rebaca-poc-command.sh'
    [ $# -gt 0 ] && run_cmd="$1" 

    if [ ! -f "${cmd}" ] ; then
    cat <<EOF > ${cmd}
#!/bin/bash
echo "Hello..."
EOF
    fi

    podman run \
        --name rebaca-poc \
        --platform linux/amd64 \
        -ti \
        --user root \
        --hostname rebaca-poc \
        \
        -d \
        --restart=always \
        -p 22044:22044 \
        \
        -e ARTIFACT_DIR="${C_HOME}/artifacts" \
        -v ${PWD}/artifacts:${C_HOME}/artifacts \
        \
        -e SHARED_DIR="${C_HOME}/shared_dir" \
        -v ${PWD}/shared_dir:${C_HOME}/shared_dir \
        \
        -v ${PWD}/vaults:/var/run/telcov10n:ro \
        \
        -v ${PWD}/${cmd}:/usr/local/bin/${cmd} \
        --workdir ${C_HOME} \
        ${IMG_TAG} ${run_cmd}
}

function run_container_script {
    run_container rebaca-poc-command.sh
}

function main {
    load_env
    setup_env
    build_image
    run_container
    # run_container_script
}

main

        # \
        # -e KUBECONFIG="${C_HOME}/artifacts/hub-kubeconfig" \
        # -e KUBEADMIN_PASSWORD_FILE="${C_HOME}/shared_dir/kubeadmin-password" \
        # -v ${hub_kc_path}:${C_HOME}/artifacts/hub-kubeconfig:ro \

