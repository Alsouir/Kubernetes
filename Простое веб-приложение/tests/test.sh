#!/usr/bin/env bash

namespace="${NAMESPACE:-default}"
configmap_name="${CONFIGMAP:-myapp-configmap}"
deployment_name="${DEPLOYMENT:-myapp-deployment}"
service_name="${SERVICE:-myapp-service}"
ingress_name="${INGRESS:-myapp-ingress}"
url="${URL:-myapp-host.ru}"
hpa_name="${HPA:-myapp-hpa}"

failed=0
all_test=0

# Test 1: ConfigMap created
test_configmap_created() {
    all_test=$((all_test + 1))
    configmap_exists=$(kubectl get configmap -n "$namespace" "$configmap_name" -o jsonpath='{.metadata.name}')
    if [  "$configmap_exists" != "$configmap_name" ]; then
        echo -e "\033[1;31mError: ConfigMap '$configmap_name' в namespace '$namespace' не существует\033[0m"
        failed=$((failed + 1))
    else 
        echo -e "\033[1;32mConfigMap '$configmap_name' в namespace '$namespace' существует\033[0m"
    fi
}

# Test 2: Deployment created
test_deployment_created() {
    all_test=$((all_test + 1))
    deployment_exists=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.metadata.name}')
    if [ "$deployment_exists" != "$deployment_name" ]; then
        echo -e "\033[1;31mError: Deployment '$deployment_name' в namespace '$namespace' не существует\033[0m"
        failed=$((failed + 1))
    else 
        echo -e "\033[1;32mDeployment '$deployment_name' в namespace '$namespace' существует\033[0m"
    fi
}

# Test 3: Deployment mounts index.html file from ConfigMap
test_deployment_mounts_configmap() {
    all_test=$((all_test + 1))
    mount_volume=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}')
    if [ "$mount_volume" != "$configmap_name" ]; then
        echo -e "\033[1;31mError: В Deployment '$deployment_name' не вмонтирован ConfigMap \033[0m"
        failed=$((failed + 1))
    else 
        echo -e "\033[1;32mВ Deployment '$deployment_name' вмонтирован ConfigMap\033[0m"
    fi

}

# Test 4: Deployment has ready Replicas
test_deployment_ready_replicas() {
    all_test=$((all_test + 1))
    ready_replicas=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.status.readyReplicas}')
    if [ "$ready_replicas" == 0 ]; then
        echo  -e "\033[1;31mError: Deployment '$deployment_name' не имеет ни одну готовую реплику\033[0m"
        failed=$((failed + 1))
    else
      echo  -e "\033[1;32mDeployment '$deployment_name' имеет одну или больше реплик в состоянии 'Ready'\033[0m"
    fi
}

# Test 5: Deployment has replicas == readyReplicas (warn on failure)
test_deployment_replicas_equal_ready() {
    all_test=$((all_test + 1))
    replicas=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.spec.replicas}')
    ready_replicas=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.status.readyReplicas}')
    if [ "$replicas" == "$ready_replicas" ]; then
        echo -e "\033[1;32mDeployment '$deployment_name' имеет все необходимые реплики в состоянии 'Ready'\033[0m"
    else
        echo -e "\033[1;31mWarning: Deployment '$deployment_name' имеет $replicas реплик, но в состоянии 'Ready' только - $ready_replicas \033[0m"
        failed=$((failed + 1))
    fi
}

# Test 6: Deployment has open port for Applications
test_deployment_open_port() {
    all_test=$((all_test + 1))
    container_port=$(kubectl get deployment -n "$NAMESPACE" "$deployment_name" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')
    if [ "$container_port" != 80 ]; then
        echo -e "\033[1;31mError: Deployment '$deployment_name' не имеет открытого порта\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mDeployment '$deployment_name' имеет открытый порт 80\033[0m"
    fi
}

# Test 7: Service created
test_service_created() {
    all_test=$((all_test + 1))
    service_exists=$(kubectl get service -n "$namespace" "$service_name" -o jsonpath='{.metadata.name}')
    if [ "$service_exists" != "$service_name" ]; then
        echo -e "\033[1;31mError: Service '$service_name' не существует\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mService '$service_name' существует\033[0m"
    fi    
}

# Test 8: Service has type ClusterIP
test_service_type_clusterip() {
    all_test=$((all_test + 1))
    service_type=$(kubectl get service -n "$namespace" "$service_name" -o jsonpath='{.spec.type}')
    if [ "$service_type" != "ClusterIP" ]; then
        echo -e "\033[1;31mError: Service '$service_name' не имеет тип ClusterIP\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mService '$service_name' имеет тип ClusterIP\033[0m"
    fi
}

# Test 9: Service has correct selector labels (from deployment)
test_service_selector_labels() {
    all_test=$((all_test + 1))
    selector_labels=$(kubectl get service -n "$namespace" "$service_name" -o jsonpath='{.spec.selector}')
    deployment_labels=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.spec.template.metadata.labels}')
    if [ "$selector_labels" != "$deployment_labels" ]; then
        echo -e "\033[1;31mError: Service '$service_name' не имеет правильных меток(selector labels)\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mService '$service_name' имеет правильные метки (selector labels)\033[0m"
    fi
    
}

# Test 10: Service has opened port
test_service_open_port() {
    all_test=$((all_test + 1))
    service_port=$(kubectl get service -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
    if [ "$service_port" != 80 ]; then
        echo -e "\033[1;31mError: Service '$service_name' не имеет открытого порта 80\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mService '$service_name' имеет открытый порт 80\033[0m"
    fi
    
}

# Test 11: Service opened port == deployment port
test_service_port_matches_deployment() {
    all_test=$((all_test + 1))
    service_port=$(kubectl get service -n "$namespace" "$service_name" -o jsonpath='{.spec.ports[0].port}')
    container_port=$(kubectl get deployment -n "$namespace" "$deployment_name" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}')
    if [ "$service_port" != "$container_port" ]; then
        echo -e "\033[1;31mError: Порт Service '$service_name' не соответствует порту Deployment '$deployment_name'\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mПорт Service '$service_name' соответствует порту Deployment '$deployment_name'\033[0m"
    fi
}

# Test 12: Ingress created
test_ingress_created() {
    all_test=$((all_test + 1))
    ingress_exists=$(kubectl get ingress -n "$namespace" "$ingress_name" -o jsonpath='{.metadata.name}')
    if [ "$ingress_exists" != "$ingress_name" ]; then
        echo -e "\033[1;31mError: Ingress '$ingress_name' не существует\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mIngress '$ingress_name' существует в namespace '$namespace\033[0m"
    fi
}

# Test 13: Ingress has incorrect url
test_ingress_url_incorrect() {
    all_test=$((all_test + 1))
    ingress_url=$(kubectl get ingress -n "$namespace" "$ingress_name" -o jsonpath='{.spec.rules[0].host}')
    if [ "$ingress_url" != "$url" ]; then
        echo -e "\033[1;31mError: Ingress '$ingress_name' имеет не корректный URL: $ingress_url\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mIngress '$ingress_name' имеет корректный URL: $ingress_url\033[0m"
    fi
}

# Test 14: Ingress has correct annotation (warn on failure)
test_ingress_annotation() {
    all_test=$((all_test + 1))
    ingress_annotation=$(kubectl get ingress -n "$namespace" "$ingress_name" -o jsonpath='{.metadata.annotations}')
    if [ -z "$ingress_annotation" ]; then
        echo -e "\033[1;31mWarning: Ingress '$ingress_name' не имеет annotation \033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mIngress '$ingress_name' имеет annotation\033[0m"
    fi
}

# Test 15: Ingress points to service portable
test_ingress_service_target() {
    all_test=$((all_test + 1))
    ingress_service=$(kubectl get ingress -n "$namespace" "$ingress_name" -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.name}')
    if [ "$ingress_service" != "$service_name" ]; then
        echo -e "\033[1;31mError: Ingress '$ingress_name' не правильно указывает на Service '$service_name'\033[0m"
       failed=$((failed + 1))
    else
        echo -e "\033[1;32mIngress '$ingress_name' правильно указывает на Service '$service_name'\033[0m"
    fi
}

# Test 16: External HTTP(S) call to application is OK (text? + 200 OK)
test_application_https_response() {
    all_test=$((all_test + 1))
    ingress_url=$(kubectl get ingress -n "$namespace" "$ingress_name" -o jsonpath='{.spec.rules[0].host}')
    http_response=$(curl -k -s -o /dev/null -w "%{http_code}" "https://$ingress_url")
    if [ "$http_response" != 200 ]; then
        echo -e "\033[1;31mError: Страница по '$ingress_url' вернуло код состояния HTTP $http_response\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mСтраница по '$ingress_url' вернуло код состояния HTTP 200 OK\033[0m"
    fi
}

# Test 17: HPA created
test_hpa_created() {
    all_test=$((all_test + 1))
    hpa_exists=$(kubectl get hpa -n "$namespace" "$hpa_name" -o jsonpath='{.metadata.name}' 2>/dev/null)
    if [ "$hpa_exists" != "$hpa_name" ]; then
        echo -e "\033[1;31mError: HPA '$hpa_name' не существует в namespace '$namespace'\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mHPA '$hpa_name' существует в namespace '$namespace'\033[0m"
    fi
}

# Test 18: HPA targets to deployment (or other check)
test_hpa_targets_deployment() {
    all_test=$((all_test + 1))
    hpa_target=$(kubectl get hpa -n "$namespace" "$hpa_name" -o jsonpath='{.spec.scaleTargetRef.name}')
    if [ "$hpa_target" != "$deployment_name" ]; then
        echo -e "\033[1;31mError: HPA '$hpa_name' не содержит Deployment '$deployment_name'\033[0m"
        failed=$((failed + 1))
    else
        echo -e "\033[1;32mHPA '$hpa_name' содержит '$deployment_name'\033[0m"
    fi
}

run_all_tests() {
    test_configmap_created
    test_deployment_created
    test_deployment_mounts_configmap
    test_deployment_ready_replicas
    test_deployment_replicas_equal_ready
    test_deployment_open_port
    test_service_created
    test_service_type_clusterip
    test_service_selector_labels
    test_service_open_port
    test_service_port_matches_deployment
    test_ingress_created
    test_ingress_url_incorrect
    test_ingress_annotation
    test_ingress_service_target
    test_application_https_response
    test_hpa_created
    test_hpa_targets_deployment
}

run_all_tests

echo
if [ "$failed" == 0 ]; then
    echo -e "\033[1;32mfailed: $failed                   passed: $(($all_test-$failed))                   all_tests: $all_test \033[0m"
else 
    echo -e "\033[1;31mfailed: $failed                   passed: $(($all_test-$failed))                   all_tests: $all_test  \033[0m"
fi