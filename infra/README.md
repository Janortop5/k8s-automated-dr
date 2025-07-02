# Setup Jenkins for k8s-automated-dr
AFTER RUNNING THE INFRA's TERRAFORM CODE AND ANSIBLE TASKS.

Below is the quickest path to hook k8s-automated-dr Jenkins box up to its GitHub repo so every push kicks off a build.

## 0  Login and Create User
1. Access the Jenkins server on `https://<jenkins-node-ip>.nip.io/`. <-- this is generated from the ansible output.
1. Copy the Initial Jenkins Admin password from the Ansible task 'Set Jenkins admin password fact' and paste in the Initial password page.
2. In the plugins page, select the option to install the suggested plugins.
3. Create the First Admin User and Password.

## 1  Install the needed plugins

> THESE PLUGINS ARE ALREADY PART OF THE SUGGESTED DEFAULT PLUGINS SO SKIP THIS STEP. IF NOT AVAILABLE (e.g Kubernetes plugin), MANUALLY INSTALL THEM.
1. **Manage Jenkins → Manage Plugins → Available**
2. Search and install (no restart required for recent LTS versions):

   * **Kubernetes** plugin (*add credentials to jenkins and enable remote actions*)
   * **GitHub** plugin (*adds web-hooks endpoint & creds helpers*)
   * **Git** plugin (already bundled in most installs)
   * **Pipeline** (if you want to use a `Jenkinsfile`, highly recommended)


## 2A  Create a GitHub token for Jenkins

1. In GitHub **Settings → Developer settings → Personal access tokens**
2. *Generate new token (classic)* → give it:

   * **`repo`** (read your code)
   * **`admin:repo_hook`** (set up the webhook automatically)
     (*If you’d rather add the webhook by hand you can skip this scope.*)
3. Copy the token – you’ll only see it once.

## 2B  Create a Registry (e.g. Dockerhub) token for Jenkins

1. In Dockerhub **Click on Avatar → Account settings → Personal access tokens**
2. *Generate new token* → give it:

   * **`Read & Write`** (read and write to your registry repositories)
   * *access token description* → k8s-automated-dr
3. Copy the token – you’ll only see it once.



## 3A  Add the token to Jenkins credentials

1. **Manage Jenkins → Credentials → (choose global store)**
2. **Add Credentials (GitHub)**

   * Kind: **username with password**
   * Username: *paste username*
   * Password: *paste the PAT*
   * ID / Description: `github-pat` 
3. **Repeat for Dockerhub**
4. **Add Credentials (Kubernetes)**: It will be generated in ansible directory after running terraform/ansible

   * a. 
      * Kind: **secret file**
      * Filename: *kubeconfig-<>.yaml*
      * ID / Description: `kubeconfig-prod` 
   * b.
      * Kind: **secret file**
      * Filename: *jenkins-kubeconfig.yaml *
      * ID / Description: `k8s-jenkins-agent`     
> KUBECONFIG IS GENERATED IN THE ANSIBLE OUTPUT IN TASK * Show local kubeconfig path and copy/paste hint * in tasks file '*bootstrap_master.yml*'


## 3B Configure Kubernetes Cloud in Jenkins
1. Go to Manage Jenkins → Clouds → New Cloud
2. Add a new Kubernetes cloud:

   *Cloud name -> k8s-automated-dr
   * Type -> kubernetes
3. Fill in:

   * Kubernetes URL <--- Find in kubeconfig generated in ansible directory
   * Attach your credentials
   * Customize pod template if needed
   * Test the connection


> DIRECTIONS FOR THE ABOVE STEPS

Where the token ends up & how Jenkins consumes it?
* Playbook output
The task writes a file named, e.g.,

```bash
./kubeconfig-<master_private_ip>.yaml
./jenkins-kubeconfig.yaml
```

* Inside you will see:

```yaml
users:
- name: jenkins
  user:
    token: eyJhbGciOiJSUzI1NiIsImtpZCI6I…   # ← plain JWT
```

```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tL
```

The CA bundle is already Base-64, but the token is plain text – that’s
exactly what the Kubernetes API expects.

* Upload the file to Jenkins once: Manage Jenkins → Manage Credentials → (Global) → Add Credentials

   Kind: Kubernetes configuration (kubeconfig)
   File: select the jenkins-kubeconfig.yaml you just generated
   Give it an ID such as k8s-jenkins-agent.

* Tell the Kubernetes Cloud to use it: Manage Jenkins → Manage Nodes and Clouds → Configure Clouds → Kubernetes

   Field	What to enter. 
   Kubernetes URL	https://<master-PRIVATE-IP>:6443.
   Kubernetes server certificate key -> copy value of `certificate-authority-data`.
   Credentials	choose k8s-jenkins-agent.
   Kubernetes Namespace	default -> 
   TLS / Certificate	Leave blank – the CA in the kube-config is enough

* Save. The plugin loads the kube-config, extracts the token & CA, and starts using the API immediately.

   Nothing else to copy – the token Jenkins needs is already inside the file.
   Whenever the playbook refreshes the token (e.g. re-run in 24 h) just upload
   the new kube-config or replace the credential file; Jenkins picks it up
   without a restart.


## 4  Create the job

### Easiest: *Multibranch Pipeline* (auto-discovers branches & PRs)

1. Jenkins dashboard → **New Item**
2. Name it, pick **Multibranch Pipeline** → OK
3. In **Branch Sources**:

   * **Add source → GitHub**
   * Credentials: choose your `github-pat`
   * Owner / Repository: enter `<your-GH-user>/<repo>`
4. 👇 Expand **Build Triggers** and tick **“Scan by webhook”**.
   Jenkins shows you its webhook endpoint:
   `https://<jenkins-host>/github-webhook/`

Click **Save** → Jenkins will scan the repo immediately, build any branch with a `Jenkinsfile`, and keep polling via the webhook.

### Lite alternative: *Freestyle* or *Single Pipeline* job

If “one branch, one job” is enough:

1. **New Item → Pipeline**
2. Under **Pipeline script**, either:

   * **SCM → Git** and point to your repo (supply creds) — or —
   * Use **Pipeline script from SCM** to run the `Jenkinsfile` in the repo.
3. In **Build Triggers** tick **“GitHub hook trigger for GITScm polling”**.



## 5  Add (or verify) the webhook

*If you gave the token the `admin:repo_hook` scope, Jenkins auto-creates it the first time the job saves. If not:*

1. GitHub repo → **Settings → Webhooks** → Add webhook
2. **Payload URL:** `https://<jenkins-host>/github-webhook/`
3. **Content-type:** `application/json`
4. **Secret:** *(leave blank or set and mirror in the job settings)*
5. **Events:** **Just the push event** (and optionally PR events) → Save.

GitHub will ping the endpoint; you should see “*Payload delivered*” and a 200‐OK response.


## 6  Lock it down 

| Quick check                     | Why                                                                                                          |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **HTTPS** instead of plain HTTP | Your PAT travels in the webhook header. A self-signed cert or Let’s Encrypt via Nginx reverse-proxy is fine. |
| **Controller executors = 0**    | Even for a hobby box, it helps avoid “works on my machine” surprises when you later add agents.              |
| **Backup your `JENKINS_HOME`**  | At least tarball it once in a while.                                                                         |



### That’s it!

Push a commit → GitHub fires a webhook → Jenkins job appears or rebuilds in the UI. If anything doesn’t trigger:

* Check **GitHub → Webhooks → Recent Deliveries** for non-200 codes.
* In Jenkins, **Manage Jenkins → System Log → `com.cloudbees.jenkins.GitHubWebHook`** for incoming hook traces.

