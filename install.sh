#!/bin/bash

# ==========================================================================
#  ZappBot Original - Instalador Profissional
#  Baseado no projeto dinho17593/zappbot-painel
# ==========================================================================

# Cores para o terminal
RED=\'\\033[0;31m\'
GREEN=\'\\033[0;32m\'
YELLOW=\'\\033[1;33m\'
BLUE=\'\\033[0;34m\'
PURPLE=\'\\033[0;35m\'
CYAN=\'\\033[0;36m\'
NC=\'\\033[0m\'

# Configurações do Projeto
PROJECT_NAME="ZappBot Original"
TARGET_DIR="/var/www/zappbot-original"
REPO_URL="https://github.com/Vandersonmarc/zappbot-original.git"
PM2_NAME="zappbot-original"

# Função para exibir o banner
show_banner() {
    clear
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}          🤖  $PROJECT_NAME - INSTALADOR OFICIAL  🤖          ${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${WHITE}  Instalador aprimorado para a versão original do ZappBot.  ${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# Função para exibir mensagens de status
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# Verificar se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    log_error "Por favor, execute este script como root (sudo bash install.sh)."
fi

# 1. Preparação do Sistema
show_banner
log_info "Preparando o sistema e instalando dependências básicas..."
apt-get update -qq
apt-get install -y curl git wget unzip build-essential python3 ffmpeg whiptail -qq > /dev/null 2>&1
log_success "Dependências básicas instaladas."

# 2. Menu de Opções (Whiptail)
OPTION=$(whiptail --title "$PROJECT_NAME" --menu "Escolha uma opção:" 15 60 4 \
"1" "Instalação Completa (Nova)" \
"2" "Atualizar Projeto (Manter Dados)" \
"3" "Configurar SSL/Nginx" \
"4" "Sair" 3>&1 1>&2 2>&3)

case $OPTION in
    1) log_info "Iniciando Instalação Completa..." ;;
    2) log_info "Iniciando Atualização..." ;;
    3) log_info "Iniciando Configuração de SSL/Nginx..." ;;
    *) exit 0 ;;
esac

# 3. Lógica de Instalação/Atualização
if [ "$OPTION" == "1" ] || [ "$OPTION" == "2" ]; then
    
    # Backup se for atualização
    if [ "$OPTION" == "2" ] && [ -d "$TARGET_DIR" ]; then
        BKP_DIR="/root/zappbot_original_backup_$(date +%Y%m%d_%H%M%S)"
        log_info "Criando backup em $BKP_DIR..."
        mkdir -p "$BKP_DIR"
        cp "$TARGET_DIR/.env" "$BKP_DIR/" 2>/dev/null
        cp "$TARGET_DIR"/*.json "$BKP_DIR/" 2>/dev/null
        cp -r "$TARGET_DIR/sessions" "$BKP_DIR/" 2>/dev/null
        cp -r "$TARGET_DIR/auth_sessions" "$BKP_DIR/" 2>/dev/null
        log_success "Backup concluído."
    fi

    # Download do Código
    log_info "Baixando a versão mais recente do GitHub..."
    if [ -d "$TARGET_DIR" ]; then
        cd "$TARGET_DIR"
        git fetch --all
        git reset --hard origin/main
    else
        mkdir -p "/var/www"
        git clone "$REPO_URL" "$TARGET_DIR"
        cd "$TARGET_DIR"
    fi
    log_success "Código fonte atualizado."

    # Restauração do Backup
    if [ -d "$BKP_DIR" ]; then
        log_info "Restaurando dados do backup..."
        cp "$BKP_DIR/.env" "$TARGET_DIR/" 2>/dev/null
        cp "$BKP_DIR"/*.json "$TARGET_DIR/" 2>/dev/null
        cp -r "$BKP_DIR/sessions" "$TARGET_DIR/" 2>/dev/null
        cp -r "$BKP_DIR/auth_sessions" "$TARGET_DIR/" 2>/dev/null
        log_success "Dados restaurados."
    fi

    # Instalação do Node.js (se necessário)
    if ! command -v node &> /dev/null; then
        log_info "Instalando Node.js 18 (compatível com o projeto original)..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs -qq > /dev/null 2>&1
    fi

    # Instalação de Dependências do Projeto
    log_info "Instalando módulos do Node.js (isso pode demorar)..."
    npm install --silent
    log_success "Módulos instalados."

    # Configuração do .env (Interativo)
    if [ ! -f ".env" ]; then
        log_info "Configurando variáveis de ambiente (.env)..."
        
        PORT=$(whiptail --title "Configuração de Porta" --inputbox "Digite a porta para o servidor (padrão: 3000):" 10 60 "3000" 3>&1 1>&2 2>&3)
        SECRET=$(openssl rand -hex 16)
        
        cat > .env <<EOF
PORT=$PORT
SESSION_SECRET=$SECRET
# Para configurar Google OAuth, Mercado Pago ou Gemini, edite o .env manualmente após a instalação.
# Consulte o README.md para mais detalhes.
EOF
        log_success "Arquivo .env criado."
    else
        if whiptail --title "Arquivo .env existente" --yesno "Um arquivo .env já existe. Deseja editá-lo agora?" 10 60; then
            nano .env
        fi
    fi

    # Permissões
    log_info "Ajustando permissões..."
    mkdir -p uploads sessions auth_sessions
    chmod -R 777 uploads sessions auth_sessions *.json 2>/dev/null
    log_success "Permissões ajustadas."

    # Inicialização com PM2
    log_info "Iniciando aplicação com PM2..."
    npm install pm2 -g --silent
    pm2 delete "$PM2_NAME" 2>/dev/null
    pm2 start server.js --name "$PM2_NAME"
    pm2 save
    pm2 startup
    log_success "Aplicação rodando no PM2."
fi

# 4. Configuração de Nginx e SSL
if [ "$OPTION" == "1" ] || [ "$OPTION" == "3" ]; then
    if whiptail --title "Configuração de Domínio" --yesno "Deseja configurar o Nginx e SSL (HTTPS) agora?" 10 60; then
        DOMAIN=$(whiptail --title "Domínio" --inputbox "Digite seu domínio (ex: painel.seusite.com):" 10 60 3>&1 1>&2 2>&3)
        EMAIL=$(whiptail --title "E-mail" --inputbox "Digite seu e-mail para o certificado SSL:" 10 60 3>&1 1>&2 2>&3)

        if [ ! -z "$DOMAIN" ]; then
            log_info "Configurando Nginx para $DOMAIN..."
            apt-get install -y nginx certbot python3-certbot-nginx -qq > /dev/null 2>&1
            
            NGINX_CONF="/etc/nginx/sites-available/zappbot-original"
            cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \'upgrade\';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
            ln -s -f $NGINX_CONF /etc/nginx/sites-enabled/
            rm -f /etc/nginx/sites-enabled/default
            nginx -t && systemctl restart nginx
            
            log_info "Gerando certificado SSL gratuito (Let\'s Encrypt)..."
            certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
            log_success "Nginx e SSL configurados com sucesso!"
        fi
    fi
fi

# Finalização
show_banner
echo -e "${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo ""
echo -e "${WHITE}Acesse seu painel em:${NC} ${CYAN}https://$DOMAIN${NC}"
echo -e "${WHITE}Gerenciar processo:${NC} ${YELLOW}pm2 logs $PM2_NAME${NC}"
echo ""
echo -e "${PURPLE}Obrigado por usar o ZappBot Original!${NC}"
echo "============================================================"
