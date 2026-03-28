# WSO2 SWIFT MT/MX Translator and Dashboard: Kubernetes Deployment Guide 

This guide details the steps to deploy an all-in-one setup for the **WSO2 SWIFT MT/MX Translator and Dashboard** using Kubernetes.

---

## Prerequisites

Ensure you have the following installed and configured before proceeding:

* **Kubernetes** cluster access and `kubectl` configured.
* **Docker** installed for building container images.
* **Docker Hub Account** (or any other container registry) to push the custom images.

---

## Deployment Overview

This setup involves deploying **four** main Kubernetes components:

1.  **Translator Deployment (Single Pod with up to Three Containers):**
    * `translator` container (main application)
    * `fluent-bit` container (for log forwarding)
    * `extensions` container (optional, only required if extensions are enabled)
2.  **Opensearch Deployments (Two):** The data store for the translator and dashboard.
3.  **Opensearch Dashboard Deployment:** The visualization layer, leveraging the custom SWIFT Dashboard plugin.

---

## Step-by-Step Deployment Instructions

### 1. Obtain Translator and Dashboard Artifacts 

1.  **Download Translator:** Get the latest `swift-mt-mx-translator.zip` from the [WSO2 reference-implementation-cbpr releases page](https://github.com/wso2/reference-implementation-cbpr/releases).
2.  **Download Dashboard Plugin:** Get the latest `swift-dashboard.zip` from the same [releases page](https://github.com/wso2/reference-implementation-cbpr/releases).

---

### 2. Build and Push the Translator Docker Image 

1.  **Prepare Directory:** 
- Create a directory named `translator-deployment`. 
    ```bash
    mkdir translator-deployment
    cd translator-deployment
    ```
- Extract the downloaded translator package (e.g., `swift-mt-mx-translator-1.0.0.zip`) and copy the **`swiftMtMxTranslator.jar`**. 
- Copy **`extensions.jar`** (if applicable)
- Rename and copy the **`translator-dockerfile`** to **`Dockerfile`**

2.  **Build Image:** 

    Build the Docker image.
    ```bash
    docker build -t swift-translator:latest .
    ```
3.  **Tag & Push Image:** 

    Tag the image with your registry name. **Replace `<your-registry>`** with your actual username or registry path.
    ```bash
    docker tag swift-translator:latest <your-registry>/swift-translator:latest
    ```
    Push the image to your container registry. 
    ```bash
    docker push <your-registry>/swift-translator:latest
    ```

---

### 3. Build and Push the Dashboard Docker Image 

1.  **Prepare Directory:** 
- Create a directory named `dashboard-deployment`. 
    ```bash
    mkdir translator-deployment
    cd translator-deployment
    ```
- Copy the downloaded **`swift-dashboard.zip`**
- Rename and copy the **`dashboard-dockerfile`** to **`Dockerfile`**

2.  **Verify Dockerfile:** 
    
    Before building, open the `Dockerfile` and ensure the version name of the Dashboard ZIP file (`swift-dashboard-1.0.0.zip`) matches the file you copied into the directory.**

3.  **Build Image:** Build the Docker image.
    ```bash
    docker build -t swift-dashboard:latest .
    ```
4.  **Tag & Push Image:**  

    Tag the image with your registry name. **Replace `<your-registry>`** with your actual username or registry path.
    ```bash
    docker tag swift-dashboard:latest <your-registry>/swift-dashboard:latest
    ```
    Push the image to your container registry. 
    ```bash
    docker push <your-registry>/swift-dashboard:latest
    ```
    *(**Note:** Ensure your Kubernetes manifest (`wso2-swift-translator-k8s.yaml`) uses the correct registry paths for both images.)*

---

### 4. Configure Kubernetes Environment (VM Max Map Count) 

Before deployment, if you are running Kubernetes on a local VM (like Minikube or Docker Desktop), you must increase the maximum memory map count (`vm.max_map_count`) for **Opensearch** to function correctly.

1.  **Access VM Shell:** Enter the shell environment of your Kubernetes VM.
    ```bash
    rdctl shell # Example for Rancher Desktop
    # Use 'minikube ssh' for Minikube, or relevant command for your environment
    ```
2.  **Increase Max Map Count:** Set the `vm.max_map_count` kernel parameter.
    ```bash
    sudo sysctl -w vm.max_map_count=262144
    ```

---

### 5. Deploy to Kubernetes 

1. Apply secrets & config maps 
    
    Modify opensearch-secret.yaml with your default credentials and apply configurations.
   ```bash
    kubectl apply -f opensearch-secret.yaml
    kubectl create configmap translator-config --from-file=Config.toml
    ```
2. Apply the combined Kubernetes YAML file to deploy all components (Translator, Opensearch, and Dashboard).
    ```bash
    kubectl apply -f wso2-swift-translator-k8s.yaml
    ```

---

### 6. Monitor and Verify Deployment 

1.  **Check Deployments:** Verify that all deployments are up and running.
    ```bash
    kubectl get deployments
    ```
2.  **Check Pod Status:** Monitor the status of the created Pods.
    ```bash
    kubectl get pods
    ```
    *Verify that all pods, including the Opensearch and Dashboard ones, are in the **Running** state.*
