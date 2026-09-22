# Container tools

Docker rootful／Podman rootless 的 image 建置與容器工具。Docker 預設使用 system daemon（`/var/run/docker.sock`），以下主機端指令以一般使用者執行。

## 安裝／更新工具

將腳本複製到 `~/.local/bin/`，並安裝 fakehome 至 `~/.local/usr/home/`；保留既有 fakehome 檔案。

```bash
./setup.sh install
export PATH="$HOME/.local/bin:$PATH"
```

## 設定預設引擎

設定會持久保存，建置與啟動容器時自動套用，不需要手動 source 環境腳本。

```bash
./setup.sh setengine podman
# 或
./setup.sh setengine docker
```

選擇順序：`--engine` > `CONTAINER_ENGINE` > 儲存設定 > `docker`。

## 建置 image

列出 `containerfiles/` 的 recipes，以名稱或清單編號建置。

```bash
./setup.sh build --list
./setup.sh build ubuntu_2204_rv11
./setup.sh build 1
./setup.sh build ubuntu_2204_rv11 --no-cache
```

Docker 預設使用 `/var/run/docker.sock`；若 daemon 使用其他 socket，可設定：

```bash
CONTAINER_DOCKER_HOST=unix:///path/to/docker.sock ./setup.sh build 8
```

預設 image 名稱為 `<主機使用者名稱>/<recipe 檔名>:latest`（例如 `elwin/ubuntu_2204_rv11:latest`），也可自訂：

```bash
CONTAINER_IMAGE=my-rv11:dev ./setup.sh build ubuntu_2204_rv11
```

## 列出／啟動容器

`--list` 列出本專案 images，`LABEL` 欄位顯示 `io.container-tools.recipe` 的內容。

```bash
goto_container.sh --list
goto_container.sh ubuntu_2204_rv11
goto_container.sh "$(id -un)/ubuntu_2204_rv11:latest"
goto_container.sh my-rv11:dev bash -c 'id; pwd'
```

預設進入 Bash，將家目錄的 'workspace' 掛載至 `/workspace`，fakehome 掛載至 `/home/$USER`。退出後移除容器，保留掛載目錄的資料。

## 臨時切換引擎

`--engine` 放在 recipe／image 前，不改寫預設設定。Docker 與 Podman 的 images 需分別建置。

```bash
./setup.sh build --engine docker ubuntu_2204_rv11
goto_container.sh --engine docker --list
goto_container.sh --engine docker ubuntu_2204_rv11
```

## 容器內使用 sudo

容器內可免密碼使用 sudo；一般編輯與建置不需 sudo。

```bash
sudo -n id
sudo apt-get update
```

## 移除工具

移除未被修改的已安裝腳本，保留 fakehome、引擎設定與 images。

```bash
./setup.sh uninstall
```

## 查看說明

```bash
./setup.sh --help
./setup.sh build --help
goto_container.sh --help
```
