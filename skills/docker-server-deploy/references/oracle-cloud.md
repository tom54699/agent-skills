# Oracle Cloud

## CPU 架構

Ampere A1 是 ARM64：

- image 只建 `linux/arm64`
- GitHub Actions 的 build job 用 ARM runner（例如 `ubuntu-24.04-arm`），不用 QEMU 模擬，速度快很多

## 開 port 要開兩層

1. **VCN 的 Security List 或 Network Security Group**：加入 80、443 的 ingress rule
2. **主機上的 iptables**：Oracle 提供的 Ubuntu image 預設只允許 SSH，其他連線會被最後一條 `REJECT` 擋掉

主機防火牆的調整要先和使用者確認。做法是插入在 `REJECT` 那條**之前**：

```bash
sudo iptables -L INPUT --line-numbers          # 找到 REJECT 那條的行號，例如 6
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

**不要清空（flush）iptables**。Oracle 的 image 裡有開機與儲存需要的規則，清空可能讓 instance 出問題。

## 預設使用者

- Ubuntu image：`ubuntu`
- Oracle Linux image：`opc`

## 資源

免費額度的 Ampere A1 資源有上限，多個專案共用一台時，替每個服務設定 `mem_limit`，並在部署紀錄裡記下各服務的用量。
