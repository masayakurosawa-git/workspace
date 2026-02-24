## ✅ 前提条件（公式ガイドより）

Ansible は 制御ノード（Control Node） にインストールします。

この制御ノードから SSH を使って管理対象ホストを制御します。

公式ドキュメント内では Ansible のインストール方法として主に pip / pipx を使う方法 が解説されています。

---
</br>
</br>

## 📌 1. Homebrew を利用して Python3 を準備する

まず Homebrew で Python を用意します。
```bash
# Homebrew の更新
brew update

# Python3 をインストール
brew install python
```
※すでに Python3 があればこのステップは不要です。

---
</br>
</br>

## 📌 2. Python の pip を確認する
公式では Python3 の pip が利用可能であることを推奨しています。
```bash
python3 -m pip --version
```
▼ 確認
```bash
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$ python3 -m pip --version
pip 24.0 from /Users/kurosawamasaya/.pyenv/versions/3.12.2/lib/python3.12/site-packages/pip (python 3.12)
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$
```
もし pip が無い場合は：
```bash
python3 -m ensurepip --upgrade
```
---
</br>
</br>

## 📌 3. Ansible をインストールする（公式推奨）
公式ドキュメントでは pip / pipx でのインストールが書かれていますが、macOS は pip が使いやすいので pip インストール 版を紹介します。
```bash
pip install --user ansible
```
---
</br>
</br>

## 📌 4. PATH を通す（必要な場合）

pip のユーザーモードでインストールした場合はパス追加が必要になることがあります。

zsh を使っている場合：
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```
---
</br>
</br>

## 📌 5. 動作確認

公式ドキュメントでも動作を確認することが推奨されています。
```bash
ansible --version
```
正常に出力されればインストール成功です。

---
</br>
</br>

## 🍎 Homebrew からインストールする簡易版（非公式ながら一般的）
公式では pip または pipx が推奨ですが、Homebrew から Ansible を直接入れる方法も広く利用されています：
```bash
brew install ansible
```
Homebrew 版がインストールされていればバージョン確認：
```bash
ansible --version
```
※上記方法は公式ドキュメントで直接推奨されていませんが、実務でも広く使われています（公式 pip 方式と同等の ansible 実行環境が構築可能）

---
</br>
</br>

## ⚙️ 追加で入れておくと便利なもの
公式ドキュメントでも触れられている以下があると管理が楽です：

**● pipx 版インストール（依存分離）**
```bash
pipx install ansible
```
pipx は Python CLI を隔離してインストールするツールです。

**● argcomplete でコマンド補完**
```bash
python3 -m pip install --user argcomplete
```
補完を有効にすると ansible の補完が効くようになります（bash/zsh などで）

---
</br>
</br>

## ✨ まとめ
| 方法       | 公式準拠度 | 備考                                                 |
| -------- | ----- | -------------------------------------------------- |
| pip（推奨）  | ✔️    | docs.ansible.com 推奨手段 ([Ansible Documentation][1]) |
| pipx     | ✔️    | 依存分離・最新版管理に最適 ([Ansible Documentation][1])         |
| Homebrew | ❗     | 公式に明記はないが広く利用される方法 ([Homebrew Formulae][2])        |

[1]: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html "Installing Ansible — Ansible Community Documentation"
[2]: https://formulae.brew.sh/formula/ansible?utm_source=chatgpt.com "ansible — Homebrew Formulae"


---
</br>
</br>

