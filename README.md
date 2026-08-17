# terraform-aws-infra

IaC-платформа для AWS на Terraform с полностью автоматизированным CI/CD-пайплайном на self-hosted GitLab. Инфраструктура (VPC, EC2) описывается модульным Terraform-кодом и применяется через GitLab CI/CD с обязательным ручным подтверждением `apply`, а сам AWS эмулируется через LocalStack — весь проект можно поднять и прогнать локально, без реального AWS-аккаунта.

## Архитектура

```
                        ┌─────────────────────────┐
                        │        AWS VPC          │
                        │      10.0.0.0/16        │
                        │                         │
   Internet ◄──────────►│  Internet Gateway       │
                        │           │             │
                        │           ▼             │
                        │  Route Table (0.0.0.0/0)│
                        │           │             │
                        │           ▼             │
                        │   Subnet 10.0.1.0/24    │
                        │           │             │
                        │           ▼             │
                        │     EC2 Instance        │
                        │      (t2.micro)         │
                        └─────────────────────────┘
```

Terraform-код разбит на два независимых, переиспользуемых модуля:

- **`modules/vpc`** — сеть: VPC, публичный subnet, Internet Gateway, route table с маршрутом наружу и её ассоциация с subnet
- **`modules/ec2`** — вычислительный ресурс: EC2-инстанс, размещаемый в subnet, полученном от модуля `vpc`

Окружение **`modules/environments/dev`** связывает оба модуля вместе и содержит конфигурацию AWS-провайдера, направленную на LocalStack вместо реального AWS.

## Стек

- **Terraform** (`~> 5.0` AWS provider) — описание инфраструктуры как кода
- **GitLab CE** (self-hosted, в Docker) — репозиторий и CI/CD
- **GitLab Runner** (Docker executor) — исполнение пайплайна
- **LocalStack** — локальная эмуляция AWS API (EC2/VPC)
- **Docker / Docker Compose** — окружение для всех компонентов

## CI/CD-пайплайн

Пайплайн (`.gitlab-ci.yml`) состоит из четырёх стадий, выполняющихся последовательно:

| Стадия | Job | Что делает |
|---|---|---|
| `validate` | `fmt_check` | `terraform fmt -check -recursive` — проверка форматирования |
| `validate` | `validate_check` | `terraform init -backend=false` + `terraform validate` — проверка синтаксиса и корректности конфигурации |
| `test` | `secret_detection` | встроенный GitLab-шаблон поиска секретов в коде |
| `plan` | `plan` | `terraform init` + `terraform plan -out=tfplan` — план изменений, сохраняется как артефакт |
| `apply` | `apply` | `terraform apply tfplan` — применение плана; запускается **только вручную** и только на `main` |

Разработка ведётся через feature-ветки и Merge Request'ы: `plan` прогоняется как для событий `merge_request_event`, так и для пушей в `main`, что позволяет увидеть план изменений инфраструктуры ещё до мержа.

## Как поднять локально

1. **Поднять self-hosted GitLab CE и GitLab Runner** в общей Docker-сети, зарегистрировать раннер на проект.
2. **Поднять LocalStack** в той же сети (требуется бесплатный `LOCALSTACK_AUTH_TOKEN` — см. [localstack.cloud](https://app.localstack.cloud), Hobby plan):
   ```bash
   docker run -d \
     --name localstack \
     --network gitlab-network \
     -p 4566:4566 \
     -e LOCALSTACK_AUTH_TOKEN=<токен> \
     -e SERVICES=ec2 \
     -v /var/run/docker.sock:/var/run/docker.sock \
     localstack/localstack
   ```
3. **Запушить репозиторий** в self-hosted GitLab — пайплайн запустится автоматически на MR/push.
4. **Проверить результат** через AWS CLI, направленный на LocalStack:
   ```bash
   export AWS_ACCESS_KEY_ID=test
   export AWS_SECRET_ACCESS_KEY=test
   export AWS_DEFAULT_REGION=us-east-1
   aws --endpoint-url=http://localhost:4566 ec2 describe-instances
   ```

## Проблемы и решения

В процессе настройки self-hosted окружения встретился ряд нетривиальных проблем — фиксирую их здесь, поскольку сам процесс диагностики был важной частью проекта:

- **Crash-loop GitLab CE (puma).** `external_url` был указан с портом 8080, из-за чего внутренний TCP-листенер puma и nginx конкурировали за один и тот же порт — при каждом рестарте puma получала `EADDRINUSE` и уходила в бесконечный цикл падений. Решение — вынести puma на отдельный порт (`puma['port'] = 8081`).
- **Официальный образ `hashicorp/terraform` перехватывает команды CI.** У образа собственный entrypoint, из-за чего GitLab Runner не мог выполнить shell-команды (`terraform sh` вместо реального `sh -c ...`). Решение — явно обнулить entrypoint в конфиге job: `entrypoint: [""]`.
- **Неверные пути к модулям.** Структура репозитория нестандартна (`environments` лежит внутри `modules/`, а не рядом), из-за чего исходный относительный путь `../../modules/vpc` не находил модуль. Поправлено на `../../vpc` с учётом реальной вложенности.

## Результат

Пайплайн проходит полный цикл `validate → test → plan → apply` и создаёт в LocalStack реальные ресурсы: VPC, subnet, Internet Gateway, route table с ассоциацией и EC2-инстанс — что подтверждено как логом `terraform apply` (`Apply complete! Resources: 6 added, 0 changed, 0 destroyed`), так и прямой проверкой через AWS CLI.
