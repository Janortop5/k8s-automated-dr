# Setup Jenkins for k8s-automated-dr
Below is the quickest path to hook k8s-automated-dr Jenkins box up to its GitHub repo so every push kicks off a build.

## 0  Login and Create User
1. Copy the Initial Jenkins Admin password from the Ansible task 'Set Jenkins admin password fact' and paste in the Initial password page.
2. In the plugins page, select the option to install the suggested plugins.
3. Create the First Admin User and Password.

## 1  Install the needed plugins

> THESE PLUGINS ARE PART OF THE SUGGESTED DEFAULT PLUGINS SO SKIP THIS STEP. IF NOT AVAILABLE, MANUALLY INSTALL THEM.
1. **Manage Jenkins → Manage Plugins → Available**
2. Search and install (no restart required for recent LTS versions):

   * **GitHub** plugin (*adds web-hooks endpoint & creds helpers*)
   * **Git** plugin (already bundled in most installs)
   * **Pipeline** (if you want to use a `Jenkinsfile`, highly recommended)


## 2  Create a GitHub token for Jenkins

1. In GitHub **Settings → Developer settings → Personal access tokens**
2. *Generate new token (classic)* → give it:

   * **`repo`** (read your code)
   * **`admin:repo_hook`** (set up the webhook automatically)
     (*If you’d rather add the webhook by hand you can skip this scope.*)
3. Copy the token – you’ll only see it once.



## 3  Add the token to Jenkins credentials

1. **Manage Jenkins → Credentials → (choose global store)**
2. **Add Credentials**

   * Kind: **Secret text**
   * Secret: *paste the PAT*
   * ID / Description: `github-pat` (or whatever you like)



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

