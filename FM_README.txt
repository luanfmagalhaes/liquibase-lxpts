-------------------------------------------------------------------------------------------------------------------------------------------------

01 - Executar o liquibase para se conectar com o banco de dados

    - Foi criado o script updateDataBase.sh na raiz do projeto que é o responsável por criar os arquivos necessários e executar o comando de 
    liquibase com o banco de dados configurado.

    - Primeiramente configure o arquivo db_config na raiz do projeto, para conter as informações referente ao banco de dados que deseja 
    executar o projeto fmp-liquibase.

    - Atente para a variável DEPLOY_PROFILE, por default ela vem como DEV, pois para esse profile é necessário cargas adicionais no banco,
    já o profile PRD é para ambientes de produção/homologação, pois contem execuções de scripts de carga diferentes dos de DEV

    - Após realizado a configuração, execute o script: ./updateDataBase

    - Em uma instalação nova, ou seja, criação do banco de dados do zero e execução de cargas, o comando irá demorar um pouco mais, 
    mas apenas na primeira vez. Em uma execução em um banco onde já exista as tabelas, cargas e demais informações dos schemas, a execução 
    ainda será um pouco demorada, pois ele checa tudo para validar se está correto, mas também será lento apenas na primeira execução

    - Após essa primeira execução, só será necessário uma nova, quando houver alguma alteração ou rollback a ser aplicado, e como o liquibase
    irá criar a tabelas de mapeamento de execuções, não irá reexecutar ou rechecar os scripts, sendo muito mais rápido

-------------------------------------------------------------------------------------------------------------------------------------------------

02 - Criando um novo arquivo com alterações a serem aplicadas na nova versão:

    - Caso não exista ainda o arquivo de changelog referente a versão trabalhada, crie o arquivo na pasta database/changelog no formato:
    db.changelog-X.Y.Z.xml onde X.Y.Z se refere ao numero da versão

    - Dentro deste arquivo é necessário um cabeçalho com os apontamentos para utilização das tags, veja algum já existente ou modifique conforme
    sua necessidade

    - A primeira tag a ser adicionada após o cabeçalho deve ser a que engloba a alteração e o rollback, de nome 'changeSet'. Na sua criação 
    existem alguns atributos a serem adicionados para melhor identificar o que ela está realizando, são elas:
    * id: recebe um numero que representa a ordem da execução desta alteração dentro do arquivo
    * author: recebe um texto que representa o nome/apelido/usuario que implementou tal alteração
    * context: recebe um texto que pode ser utilizado para comentar a alteração realizada
    * outros atributos que podem ser verificados no site oficial do liquibase, mas que no momento não vejo necessidade de inseri-los

    - Dentro das limitações da tag 'changeSet' será inserido tags para a alteração desejada:
    * sql: tag que irá conter dentro de si o comando sql que se deseja executar
    * createProcedure: tag que irá conter dentro de si o comando sql que se deseja executar. Nessa tag é possível inserir os delimitadores
    <![CDATA[ $comandoSql ]]>, esses delimitadores servem para ser possível a leitura do $ (dollar) dentro de um comando sql. No Postgresql
    blocos plsql, funções, entre outros, necessitam ter o $ para sua execução, e por isso, para executar esses comandos a tag createProcedure
    com esses delimitadores é necessária. Esta foi a única forma que encontrei para conseguir executar criações/edições de funções, na versão 
    atual do liquibase
    * rollback: tag que irá conter dentro de si o comando de rollback do changeSet. Caso o rollback seja de algum comando que possua $ a tag 
    createProcedure com os delimitadores <![CDATA[ $comandoSql ]]> deve ser incluída também

    - Vejamos dois exemplos de changeSet com rollback:

        a) changeSet com adição de coluna:

            <changeSet id="1" author="LFigueiredo" dbms ="postgresql" context="Add a new column tx_status in table teams">
                <sql>
                    ALTER TABLE teams ADD COLUMN IF NOT EXISTS tx_status character varying(1) COLLATE pg_catalog."default" NOT NULL DEFAULT 'E'::character varying;
                </sql>
                <rollback>
                    ALTER TABLE teams DROP COLUMN IF EXISTS tx_status;
                </rollback>
            </changeSet>

        b) changeSet com execução de bloco plsql:

            <changeSet id="1" author="LFigueiredo" dbms ="postgresql" context="Insert new parameter cell.geolocate.uri in table cfg_parameter">
                <createProcedure>
                <![CDATA[
                    do
                    $$
                        begin
                            if not exists (SELECT * FROM cfg_parameter WHERE cd_parameter='cell.geolocate.uri') then 
                                insert into cfg_parameter (
                                    cd_parameter,
                                    tx_description,
                                    tx_parameter,
                                    ts_registered,
                                    ts_modified
                                )
                                values (
                                    'cell.geolocate.uri',
                                    'Base URI to access cells by cgi',
                                    (SELECT split_part(tx_parameter, '/geolocation/v1/geolocate', 1) FROM cfg_parameter WHERE cd_parameter = 'cell.database.host'),
                                    current_date,
                                    current_date
                                );
                            end if;
                        end;
                    $$ language 'plpgsql';
                ]]>
                </createProcedure>
                <rollback>
                    delete from cfg_parameter where cd_parameter = 'cell.geolocate.uri';
                </rollback>
            </changeSet>

    - Após a criação do arquivo de changelog, é necessário realizar seu apontamento no arquivo principal (db.changelog-master.xml) 
    ao final da lista, pois o arquivo de propriedades do liquibase lê apenas as informações instruídas neste arquivo

    - Vejamos um exemplo:

        a) Adicionando o apontamento do arquivo de changelog de versao 2.1.3 (db.changelog-2.1.3.xml)

            ...
            <include file="install/database/db.install.database.xml" relativeToChangelogFile="true"/>

            <!-- Files to update database to the version 2.1.2 -->
            <include file="changelog/db.changelog-2.1.2.xml" relativeToChangelogFile="true"/>
            <include file="tags/tag.genarate-2.1.2.xml" relativeToChangelogFile="true"/>

            <!-- Files to update database to the version 2.1.3 -->
            <include file="changelog/db.changelog-2.1.3.xml" relativeToChangelogFile="true"/>
            ...

-------------------------------------------------------------------------------------------------------------------------------------------------

03 - Adicionando uma alteração ao arquivo da versão atual

    - O liquibase cria duas tabelas na base de dados, uma para fazer o controle do que já foi executado (databasechangelog) 
    e outra para controlar as execuções (databasechangeloglock)

    - Quando um update é executado, ele registra o arquivo e o id do changeSet que foi executado, então para adicionar novas execuções 
    a serem executadas na versão, é necessário criar um novo changeSet com um novo id, pois se você adicionar informações dentro de 
    um changeSet já processado e registrado na base ou modificar as informações dentro dele, dará erro no update

    - Se você realmente deseja alterar um changeSet já executado, rode o rollback para a versão anterior, assim o registro da execução
    do arquivo e id do changeSet serão apagados da tabela de controle, podendo ser executado com alterações após isso

-------------------------------------------------------------------------------------------------------------------------------------------------

04 - Executar um rollback da sua alteração

    - Como já explicado anteriormente, todo changeSet deve conter um rollback, pois só assim iremos conseguir saber o estado da base de dados 
    antes da alteração.

    - Existem algumas formas de se executar um rollback, porém, acredito que a melhor a ser utilizada no first miles seja a execução do rollback
    por tags

    - Para realizar um rollback, é necessário que exista uma tag criada em um determinado 'tempo' do código. Essas tags são geradas geralmente
    ao termino de um aglomerado de alterações no banco.

    - Foi criado um script na raiz do projeto para a execução de rollbacks, basta executar ./rollback X.Y.Z, onde X.Y.Z corresponde a versão
    que existe uma tag criada. Ao executar o comando, o liquibase irá executar todos os rollbacks existentes nos changeSets até a versão
    informada. Esses rollbacks são executados na ordem do ultimo para o primeiro, para garantir a integridade da ordenação.

    - A cada rollback executado, o registro referente ao changeSet dele é excluído da tabela de controle databasechangelog

-------------------------------------------------------------------------------------------------------------------------------------------------

05 - Criando uma tag ao finalizar todas as alterações da versão

    - Ao final das alterações referente a versão atual, é aconselhado a criação de uma tag referente a mesma, para que execuções futuras
    possam retornar a esta caso necessário.

    - Para criar uma nova tag, no padrão deste projeto, crie um arquivo na pasta database/tags no formato:
    tag.genarate-X.Y.Z.xml onde X.Y.Z se refere ao numero da versão

    - Dentro deste arquivo, além do cabeçalho, será adicionado também um changeSet contendo as informações de id, author e context, porém
    dentro do changeSet será adicionado apenas a tag 'tagDatabase', com o atributo 'tag' informando a versão

    - Vejamos um exemplo

        a) Criando o changeSet com a tag de versao 2.1.3

            ...
            <changeSet id="1" author="LFigueiredo" context="Generate tag 2.1.3">
                <tagDatabase tag="2.1.3"/>
            </changeSet>
            ...

    - Após a criação do arquivo de tag, é necessário realizar seu apontamento no arquivo principal (db.changelog-master.xml) 
    após o apontamento do arquivo de changelog desta versão.

    - Vejamos um exemplo

        a) Adicionando o apontamento do arquivo de de tag de versão 2.1.3 (tag.genarate-2.1.3.xml) ao final do changelog desta

            ...
            <include file="install/database/db.install.database.xml" relativeToChangelogFile="true"/>

            <!-- Files to update database to the version 2.1.2 -->
            <include file="changelog/db.changelog-2.1.2.xml" relativeToChangelogFile="true"/>
            <include file="tags/tag.genarate-2.1.2.xml" relativeToChangelogFile="true"/>

            <!-- Files to update database to the version 2.1.3 -->
            <include file="changelog/db.changelog-2.1.3.xml" relativeToChangelogFile="true"/>
            <include file="tags/tag.genarate-2.1.3.xml" relativeToChangelogFile="true"/>
            ...

-------------------------------------------------------------------------------------------------------------------------------------------------

06 - Repita para as versões futuras... 

-------------------------------------------------------------------------------------------------------------------------------------------------