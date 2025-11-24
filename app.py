from flask import Flask, jsonify
from flask import request 
from werkzeug.security import generate_password_hash, check_password_hash
import pymysql
import pymysql.cursors 
import os 
import smtplib 
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from werkzeug.utils import secure_filename 
from flask import send_from_directory 
import requests 
import os 

# --- Configurações do MySQL  ---
MYSQL_HOST = "127.0.0.1"
MYSQL_USUARIO = ""
MYSQL_SENHA = ""
MYSQL_BANCO = "aplicativotrilhamapl"
MYSQL_PORTA = 3306
ADMIN_REGISTER_CODE = "MAPL_ADMIN_2025"

# Inicializa o aplicativo Flask
app = Flask(__name__)

def send_welcome_email(user_email, user_name):
    """Envia um e-mail de boas-vindas para o novo usuário."""

    # Pega as credenciais das variáveis de ambiente
    sender_email = os.environ.get('EMAIL_USER')
    sender_password = os.environ.get('EMAIL_PASS')

    if not sender_email or not sender_password:
        print("[API_SERVER] ERRO DE E-MAIL: Variáveis EMAIL_USER ou EMAIL_PASS não definidas.")
        return False # Falha silenciosamente para não quebrar o cadastro

    message = MIMEMultipart("alternative")
    message["Subject"] = "Bem-vindo ao Aplicativo de Trilhas!"
    message["From"] = sender_email
    message["To"] = user_email

    # Cria o corpo do e-mail em HTML
    html = f"""
    <html>
    <body>
        <h3>Olá, {user_name}!</h3>
        <p>Seu cadastro no Aplicativo de Apoio à Trilha foi realizado com sucesso.</p>
        <p>Estamos felizes em ter você conosco.</p>
        <p>Atenciosamente,<br>Equipe MAPL</p>
    </body>
    </html>
    """

    # Adiciona o HTML ao e-mail
    message.attach(MIMEText(html, "html"))

    # Cria a conexão segura com o servidor SMTP do Gmail
    context = ssl.create_default_context()
    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
            server.login(sender_email, sender_password)
            server.sendmail(sender_email, user_email, message.as_string())
        print(f"[API_SERVER] E-mail de boas-vindas enviado para {user_email}")
        return True
    except Exception as e:
        print(f"[API_SERVER] ERRO AO ENVIAR E-MAIL: {e}")
        return False

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def conectar_mysql():
    """Função auxiliar para conectar ao banco."""
    try:
        conexao = pymysql.connect(
            host=MYSQL_HOST,
            user=MYSQL_USUARIO,
            password=MYSQL_SENHA,
            database=MYSQL_BANCO,
            port=MYSQL_PORTA,
            # Retorna os resultados como dicionários (ex: {'nome': 'Trilheiro'})
            cursorclass=pymysql.cursors.DictCursor 
        )
        return conexao
    except pymysql.Error as err:
        print(f"[API_SERVER] Erro ao conectar ao MySQL: {err}")
        return None

# --- ENDPOINT 1: Dashboard do Operador de Base ---
@app.route('/api/dashboard/geral', methods=['GET'])
def get_dashboard_geral():
    print("[API_SERVER] Recebida requisição para /api/dashboard/geral")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            # Contar total de usuários
            cursor.execute("SELECT COUNT(*) as total_usuarios FROM usuarios")
            total_usuarios = cursor.fetchone()['total_usuarios']

            # Contar total de eventos (passagens)
            cursor.execute("SELECT COUNT(*) as total_eventos FROM eventos_passagem")
            total_eventos = cursor.fetchone()['total_eventos']

            # Contar agendamentos (exemplo)
            cursor.execute("SELECT COUNT(*) as total_agendamentos FROM agendamentos")
            total_agendamentos = cursor.fetchone()['total_agendamentos']

        return jsonify({
            "total_usuarios": total_usuarios,
            "total_eventos_passagem": total_eventos,
            "total_agendamentos": total_agendamentos
        })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 2: Verificação do Guia por Tag ---
@app.route('/api/eventos/tag/<int:tag_id>', methods=['GET'])
def get_eventos_por_tag(tag_id):
    print(f"[API_SERVER] Recebida requisição para /api/eventos/tag/{tag_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            # SQL que busca os eventos e junta com o nome do usuário
            sql = """
            SELECT 
                e.timestamp_leitura, 
                e.direcao, 
                u.nome as nome_usuario,
                u.email as email_usuario
            FROM eventos_passagem e
            JOIN usuarios u ON e.id_usuario = u.id
            WHERE e.id_tag = %s
            ORDER BY e.timestamp_leitura DESC;
            """
            cursor.execute(sql, (tag_id,))
            eventos = cursor.fetchall()

            # TODO: Adicionar a lógica de "check-in mas não passou"

            return jsonify({
                "tag_solicitada": tag_id,
                "passaram_por_aqui": eventos
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 3: Registro de Novo Usuário (COM FOTO) ---
@app.route('/api/register', methods=['POST'])
def register_user():
    print("[API_SERVER] Recebida requisição para /api/register (com form-data)")

    # 1. Pega os dados do formulário (NÃO é mais request.json)
    data = request.form

    # Campos obrigatórios
    nome = data.get('nome')
    email = data.get('email')
    senha = data.get('senha')
    tipo_perfil = int(data.get('tipo_perfil', 1))

    # Campos opcionais
    telefone = data.get('telefone')
    idade = data.get('idade')
    sexo = data.get('sexo')
    admin_code = data.get('admin_code')

    if not nome or not email or not senha:
        return jsonify({"erro": "Nome, e-mail e senha são obrigatórios"}), 400

    if tipo_perfil > 1 and admin_code != ADMIN_REGISTER_CODE:
        return jsonify({"erro": "Código de administrador inválido"}), 403

    senha_hash = generate_password_hash(senha)

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Erro de conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            # 2. Inserimos o usuário primeiro, SEM a foto
            sql_insert_user = """
            INSERT INTO usuarios (nome, email, senha_hash, tipo_perfil, telefone, idade, sexo)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql_insert_user, (nome, email, senha_hash, tipo_perfil, telefone, idade, sexo))
            novo_id = cursor.lastrowid # Pegamos o ID do usuário recém-criado

            # 3. Agora, processamos a foto (se ela foi enviada)
            url_foto_final = None # Padrão
            if 'foto_perfil' in request.files:
                file = request.files['foto_perfil']

                if file and allowed_file(file.filename):
                    # Gera um nome de arquivo seguro (ex: 'usuario_1.jpg')
                    extensao = file.filename.rsplit('.', 1)[1].lower()
                    filename = f"usuario_{novo_id}.{extensao}"

                    # Salva o arquivo na pasta 'uploads/'
                    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                    file.save(filepath)

                    # Este é o caminho que salvamos no BD
                    url_foto_final = filename 

                    # 4. Atualizamos o usuário com o caminho da foto
                    sql_update_photo = "UPDATE usuarios SET url_foto_perfil = %s WHERE id = %s"
                    cursor.execute(sql_update_photo, (url_foto_final, novo_id))

            # 5. Commit de todas as mudanças (insert e update)
            conexao.commit()

            # Envia o e-mail de boas-vindas
            send_welcome_email(email, nome)

            return jsonify({
                "mensagem": "Usuário criado com sucesso!",
                "id_usuario": novo_id,
                "nome": nome,
                "tipo_perfil": tipo_perfil,
                "url_foto_perfil": url_foto_final
            }), 201

    except pymysql.Error as err:
        if conexao: conexao.rollback() # Desfaz a transação em caso de erro
        if err.args[0] == 1062:
            return jsonify({"erro": "E-mail já cadastrado"}), 409
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()


# --- ENDPOINT 4: Login ---
@app.route('/api/login', methods=['POST'])
def login_user():
    print("[API_SERVER] Recebida requisição para /api/login")
    data = request.json
    email = data.get('email')
    senha = data.get('senha')

    if not email or not senha:
        return jsonify({"erro": "E-mail e senha são obrigatórios"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Erro de conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = "SELECT * FROM usuarios WHERE email = %s"
            cursor.execute(sql, (email,))
            usuario = cursor.fetchone() # Pega o primeiro (e único) usuário

            # 1. Checa se o usuário existe
            if not usuario:
                return jsonify({"erro": "Credenciais inválidas (usuário)"}), 401 # 401 = Não autorizado

            # 2. Checa se a senha está correta
            if not check_password_hash(usuario['senha_hash'], senha):
                return jsonify({"erro": "Credenciais inválidas (senha)"}), 401

            # Login OK! Retorna os dados do usuário para o app
            return jsonify({
                "mensagem": "Login bem-sucedido!",
                "id_usuario": usuario['id'],
                "nome": usuario['nome'],
                "email": usuario['email'],
                "tipo_perfil": usuario['tipo_perfil'],
                "url_foto_perfil": usuario['url_foto_perfil']
               
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 5: Servidor de Arquivos Estáticos (para ver as fotos) ---
@app.route('/uploads/<path:filename>')
def serve_uploaded_file(filename):
    print(f"[API_SERVER] Servindo arquivo: {filename}")
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

# --- ENDPOINT 6: Iniciar uma Nova Trilha ---
@app.route('/api/trilha/iniciar', methods=['POST'])
def iniciar_trilha():
    print("[API_SERVER] Recebida requisição para /api/trilha/iniciar")
    data = request.json

    # Pega os dados do formulário
    id_usuario = data.get('id_usuario_lider')
    nome_trilha = data.get('nome_trilha')
    dificuldade = data.get('dificuldade')
    tipo = data.get('tipo')
    duracao_estimada_min = data.get('duracao_estimada_min')
    notas = data.get('notas')

    if not id_usuario or not nome_trilha or not dificuldade or not tipo:
        return jsonify({"erro": "Campos obrigatórios ausentes"}), 400

    conexao = conectar_mysql()
    if conexao is None: return jsonify({"erro": "Erro de conexão com BD"}), 500

    try:
        with conexao.cursor() as cursor:
            sql = """
            INSERT INTO trilhas_ativas 
            (id_usuario_lider, nome_trilha, dificuldade, tipo, duracao_estimada_min, notas)
            VALUES (%s, %s, %s, %s, %s, %s)
            """
            cursor.execute(sql, (id_usuario, nome_trilha, dificuldade, tipo, duracao_estimada_min, notas))
            conexao.commit()

            nova_trilha_id = cursor.lastrowid

            return jsonify({
                "mensagem": "Trilha iniciada com sucesso!",
                "id_trilha_ativa": nova_trilha_id,
            }), 201 # Criado

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao: conexao.close()

# --- ENDPOINT 7: Buscar Detalhes de uma Trilha Ativa ---
@app.route('/api/trilha/detalhes/<int:trilha_id>', methods=['GET'])
def get_detalhes_trilha(trilha_id):
    print(f"[API_SERVER] Recebida requisição para /api/trilha/detalhes/{trilha_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            # 1. Busca os dados da trilha (e formata a data)
            sql_trilha = """
            SELECT 
                nome_trilha, dificuldade, tipo, notas,
                DATE_FORMAT(iniciada_em, '%%Y-%%m-%%dT%%H:%%i:%%s') as iniciada_em_iso,
                id_usuario_lider
            FROM trilhas_ativas 
            WHERE id = %s
            """
            cursor.execute(sql_trilha, (trilha_id,))
            trilha = cursor.fetchone()

            if not trilha:
                return jsonify({"erro": "Trilha não encontrada"}), 404

            # 2. Busca o líder (nosso primeiro participante)
            id_lider = trilha.get('id_usuario_lider')
            sql_participantes = """
            SELECT nome, url_foto_perfil 
            FROM usuarios 
            WHERE id = %s
            """ 
            # TODO: No futuro, buscar todos os IDs do grupo
            cursor.execute(sql_participantes, (id_lider,))
            participantes = cursor.fetchall()

            return jsonify({
                "trilha_info": trilha,
                "participantes": participantes 
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 8: Finalizar uma Trilha Ativa ---
@app.route('/api/trilha/finalizar/<int:trilha_id>', methods=['POST'])
def finalizar_trilha(trilha_id):
    print(f"[API_SERVER] Recebida requisição para /api/trilha/finalizar/{trilha_id}")
    conexao = conectar_mysql()
    if conexao is None:
        return jsonify({"erro": "Nao foi possivel conectar ao banco"}), 500

    try:
        with conexao.cursor() as cursor:
            # Atualiza o status e o horário de conclusão
            sql = """
            UPDATE trilhas_ativas 
            SET status = 'Concluída', concluida_em = NOW() 
            WHERE id = %s
            """
            cursor.execute(sql, (trilha_id,))
            conexao.commit()

            return jsonify({
                "mensagem": "Trilha finalizada com sucesso!",
                "id_trilha_finalizada": trilha_id
            })

    except pymysql.Error as err:
        return jsonify({"erro": f"Erro de SQL: {err}"}), 500
    finally:
        if conexao:
            conexao.close()

# --- ENDPOINT 9: Buscar Clima Local ---
@app.route('/api/clima', methods=['GET'])
def get_clima():
    lat = request.args.get('lat')
    lon = request.args.get('lon')
    api_key = os.environ.get('OPENWEATHER_API_KEY')

    if not lat or not lon:
        return jsonify({"erro": "Latitude (lat) e Longitude (lon) são obrigatórias"}), 400

    if not api_key:
        print("[API_SERVER] ERRO DE CLIMA: Variável OPENWEATHER_API_KEY não definida.")
        return jsonify({"erro": "Serviço de clima indisponível"}), 503

    url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={api_key}&units=metric&lang=pt_br"

    try:
        response = requests.get(url)
        data = response.json()

        if response.status_code != 200:
            return jsonify({"erro": data.get('message', 'Erro da API de Clima')}), response.status_code

        # Filtramos apenas o que precisamos
        clima_filtrado = {
            "temp": data['main']['temp'],
            "sensacao_termica": data['main']['feels_like'],
            "descricao": data['weather'][0]['description'].capitalize(),
            "icone": data['weather'][0]['icon']
        }
        return jsonify(clima_filtrado)

    except Exception as e:
        return jsonify({"erro": f"Exceção na API de Clima: {e}"}), 500

# --- Roda o Servidor ---
if __name__ == '__main__':
    print("[API_SERVER] Iniciando servidor Flask...")
    # host='0.0.0.0' faz o servidor ser visível na sua rede local (pelo IP 192.168.15.79)
    # e também em localhost (127.0.0.1)
    app.run(host='0.0.0.0', port=5000, debug=True)