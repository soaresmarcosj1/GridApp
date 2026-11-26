<div align="center">

# GridApp

![GitHub repo size](https://img.shields.io/github/repo-size/soaresmarcosj1/GridApp?style=for-the-badge)
![GitHub language count](https://img.shields.io/github/languages/count/soaresmarcosj1/GridApp?style=for-the-badge)
![Platform macOS](https://img.shields.io/badge/macOS-14.0%2B%20(Apple%20Silicon)-000000?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.4-F05138?style=for-the-badge&logo=swift&logoColor=white)

<img src="Resources/AppIcon-preview.png" alt="Ícone do GridApp" width="140">

> Gerador nativo de **Contact Sheets** de vídeo para macOS (Apple Silicon), com pré-visualização com zoom no trackpad, edição direta de cada captura com um clique e automação pelo Finder e Apple Atalhos.

</div>

---

## Ajustes e melhorias

O projeto continua evoluindo e os principais recursos estão organizados abaixo:

- [x] Extração paralela via **AVFoundation** e fallback automático via **FFmpeg / FFprobe** (`MKV`, `AVI`, `WebM`, `FLV`, etc.)
- [x] Visualizador nativo com gesto de **pinça (zoom)** no trackpad e edição direta de frames ao passar o mouse e clicar
- [x] Layouts pré-definidos de folha (`Auto`, `16:9`, `9:16`, `4:5`, `5:4`, `1:1`) e proporção das miniaturas (`Adaptar`, `Vídeo`, `16:9`, `4:3`, `1:1`)
- [x] Cabeçalho técnico completo com tipografia e espaçamentos configuráveis por steppers
- [x] Janela de Configurações (`⌘,`) com menu lateral, temas de cor, modo Claro/Escuro/Sistema e densidade (`Compacto`, `Normal`, `Espaçoso`)
- [x] Integração com **Ação Rápida do Finder**, **Apple Atalhos** (`AppIntents`) e modo terminal `--headless`
- [x] Ícone oficial Liquid Glass compilado em `Assets.car` via GitHub Actions (`xcode-27`)
- [ ] Notarização / assinatura Apple Developer para distribuição fora do Mac local

## 💻 Pré-requisitos

Antes de começar, verifique se você atendeu aos seguintes requisitos:

- Você possui um Mac com **macOS 14.0 ou superior** (otimizado para **Apple Silicon `arm64`**).
- Você possui o **Swift / Xcode Command Line Tools** instalado (`swiftc`) para compilar localmente via `build_app.sh`.
- *(Opcional, recomendado)* Você instalou o **FFmpeg** via Homebrew para abrir formatos como `MKV`, `AVI`, `WebM` e exportar em `WebP`:
  ```bash
  brew install ffmpeg
  ```

## 🚀 Instalando o GridApp

Para compilar e instalar o **GridApp** localmente no macOS, siga estas etapas:

1. Clone o repositório:
   ```bash
   git clone https://github.com/soaresmarcosj1/GridApp.git
   cd GridApp
   ```

2. Execute o script de build (ele já embute o `Resources/Assets.car` pré-compilado e gera o `AppIcon.icns`):
   ```bash
   chmod +x build_app.sh
   ./build_app.sh
   ```

3. Instale o aplicativo na pasta `/Applications`:
   ```bash
   rm -rf /Applications/GridApp.app && cp -R GridApp.app /Applications/GridApp.app
   ```

> [!NOTE]
> Caso modifique o pacote vetorial `Resources/AppIcon.icon` no **Icon Composer**, o workflow [`.github/workflows/compile-icon.yml`](.github/workflows/compile-icon.yml) recompila automaticamente o `Resources/Assets.car` no runner `xcode-27` ao fazer `git push`.

## ☕ Usando o GridApp

### Interface principal

1. Arraste um ou mais vídeos (ou clique em **Adicionar Vídeos** / `⌘O`) para carregar na fila.
2. Navegue pelo preview usando a **pinça no trackpad** (`⌘+`, `⌘-` ou `⌘0` para `100%`).
3. Passe o mouse sobre qualquer miniatura e **clique diretamente no frame** para ajustar o timestamp exato na janela de captura (**Aplicar** / **Cancelar**).
4. Personalize colunas, proporção da folha, proporção das miniaturas, cabeçalho técnico e cores na aba **Ajustes & Design** (`⌘1`) ou salve seus próprios modelos (`⇧⌘M`).
5. Exporte em **JPEG**, **PNG**, **TIFF** ou **WebP** na aba **Exportação** (`⌘2`) ou em lote para múltiplos vídeos marcados na fila (`⇧⌘E`).

### Atalhos de teclado principais

| Atalho | Ação |
| --- | --- |
| `⌘O` | Adicionar vídeos à fila |
| `⌘S` / `⇧⌘S` | Salvar Contact Sheet atual / Salvar Como |
| `⇧⌘E` | Exportar selecionados ou toda a fila |
| `⇧⌘C` | Copiar Contact Sheet para a Área de Transferência |
| `⌘R` | Recapturar frames do vídeo atual |
| `⌘,` | Abrir Configurações do GridApp |
| `⌘1` / `⌘2` | Alternar entre *Ajustes & Design* e *Exportação* |

### Uso sem abrir a janela (Finder, Atalhos e Terminal)

- **Finder (Ação Rápida):** ao abrir o app pela primeira vez, ele instala a ação *"Criar Contact Sheet (GridApp)"* em `~/Library/Services` para clicar com o botão direito em vídeos ou pastas.
- **Apple Atalhos:** utilize a ação nativa **"Criar Contact Sheet de Vídeo"** (com suporte a execução em segundo plano e escolha opcional de modelo).
- **Terminal (`--headless`):**
  ```bash
  "/Applications/GridApp.app/Contents/MacOS/GridApp" --headless /caminho/do/video.mp4
  ```

## 📫 Contribuindo para o GridApp

Para contribuir com o **GridApp**, siga estas etapas:

1. Bifurque este repositório.
2. Crie um branch: `git checkout -b <nome_branch>`.
3. Faça suas alterações e confirme-as: `git commit -m '<mensagem_commit>'`.
4. Envie para o branch original: `git push origin <nome_branch>`.
5. Crie a solicitação de pull.

Como alternativa, consulte a documentação do GitHub em [como criar uma solicitação pull](https://docs.github.com/pt/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request).

## 🤝 Colaboradores

Agradecemos às seguintes pessoas que contribuíram para este projeto:

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/soaresmarcosj1" title="Perfil de Marcos no GitHub">
        <img src="https://github.com/soaresmarcosj1.png" width="100" alt="Foto de Marcos no GitHub"/><br>
        <sub>
          <b>Marcos (soaresmarcosj1)</b>
        </sub>
      </a>
    </td>
  </tr>
</table>

## 📝 Licença

Este repositório ainda não possui um arquivo de licença definido. Caso deseje disponibilizar o código abertamente, adicione um arquivo `LICENSE` (como MIT) na raiz do projeto.

---

<div align="center">
  <sub>README estruturado com base no <a href="https://github.com/iuricode/readme-template">iuricode/readme-template</a>.</sub>
</div>
