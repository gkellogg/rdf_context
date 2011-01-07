if defined?(::ActiveRecord::VERSION::MAJOR) && ::ActiveRecord::VERSION::MAJOR == 2
  module RdfContext
    autoload :AbstractSQLStore, File.join(File.dirname(__FILE__), 'abstract_sql_store')

    # ActiveRecord store context-ware and formula-aware implementation.
    #
    # Uses an ActiveRecord::Base.connection to run statements
    #
    # It stores it's triples in the following partitions:
    # - Asserted non rdf:type statements
    # - Asserted rdf:type statements (in a table which models Class membership). The motivation for this partition is primarily query speed and scalability as most graphs will always have more rdf:type statements than others
    # - All Quoted statements
    #
    #  In addition it persists namespace mappings in a seperate table
    class ActiveRecordStore < AbstractSQLStore
      # Create a new ActiveRecordStore Store
      # @param [URIRef] identifier
      # @param[Hash] configuration Specific to type of storage
      # @return [ActiveRecordStore]
      def initialize(identifier = nil, configuration = {})
        super(identifier, configuration)
        @autocommit_default = false
      end

      def open(options)
      end

      def close(commit_pending_transactions = false)
        ActiveRecord::Base.connection.commit_db_transaction if commit_pending_transactions
      end

      # Create necessary tables and indecies for this database
      def setup
        executeSQL(CREATE_ASSERTED_STATEMENTS_TABLE % @internedId)
        executeSQL(CREATE_ASSERTED_TYPE_STATEMENTS_TABLE % @internedId)
        executeSQL(CREATE_QUOTED_STATEMENTS_TABLE % @internedId)
        executeSQL(CREATE_NS_BINDS_TABLE % @internedId)
        executeSQL(CREATE_LITERAL_STATEMENTS_TABLE % @internedId)
      
        # Create indicies
        {
          asserted_table => {
            "#{@internedId}_A_termComb_index" => %w(termComb),
            "#{@internedId}_A_s_index" => %w(subject),
            "#{@internedId}_A_p_index" => %w(predicate),
            "#{@internedId}_A_o_index" => %w(object),
            "#{@internedId}_A_c_index" => %w(context),
          },
          asserted_type_table => {
            "#{@internedId}_T_termComb_index" => %w(termComb),
            "#{@internedId}_T_member_index" => %w(member),
            "#{@internedId}_T_klass_index" => %w(klass),
            "#{@internedId}_T_c_index" => %w(context),
          },
          literal_table => {
            "#{@internedId}_L_termComb_index" => %w(termComb),
            "#{@internedId}_L_s_index" => %w(subject),
            "#{@internedId}_L_p_index" => %w(predicate),
            "#{@internedId}_L_c_index" => %w(context),
          },
          quoted_table => {
            "#{@internedId}_Q_termComb_index" => %w(termComb),
            "#{@internedId}_Q_s_index" => %w(subject),
            "#{@internedId}_Q_p_index" => %w(predicate),
            "#{@internedId}_Q_o_index" => %w(object),
            "#{@internedId}_Q_c_index" => %w(context),
          },
          namespace_binds => {
            "#{@internedId}_uri_index" => %w(uri),
          }
        }.each_pair do |tablename, indicies|
          indicies.each_pair do |index, columns|
            executeSQL("CREATE INDEX #{index} on #{tablename} ('#{columns.join(', ')}')")
          end
        end
      end
    
      # Teardown DB files
      def teardown
        # Drop indicies
        {
          asserted_table => {
            "#{@internedId}_A_termComb_index" => %w(termComb),
            "#{@internedId}_A_s_index" => %w(subject),
            "#{@internedId}_A_p_index" => %w(predicate),
            "#{@internedId}_A_o_index" => %w(object),
            "#{@internedId}_A_c_index" => %w(context),
          },
          asserted_type_table => {
            "#{@internedId}_T_termComb_index" => %w(termComb),
            "#{@internedId}_T_member_index" => %w(member),
            "#{@internedId}_T_klass_index" => %w(klass),
            "#{@internedId}_T_c_index" => %w(context),
          },
          literal_table => {
            "#{@internedId}_L_termComb_index" => %w(termComb),
            "#{@internedId}_L_s_index" => %w(subject),
            "#{@internedId}_L_p_index" => %w(predicate),
            "#{@internedId}_L_c_index" => %w(context),
          },
          quoted_table => {
            "#{@internedId}_Q_termComb_index" => %w(termComb),
            "#{@internedId}_Q_s_index" => %w(subject),
            "#{@internedId}_Q_p_index" => %w(predicate),
            "#{@internedId}_Q_o_index" => %w(object),
            "#{@internedId}_Q_c_index" => %w(context),
          },
          namespace_binds => {
            "#{@internedId}_uri_index" => %w(uri),
          }
        }.each_pair do |tablename, indicies|
          tn = "#{@internedId}_#{tablename}"
          indicies.each_pair do |index, columns|
            executeSQL("DROP INDEX #{index} ON #{tn}")
          end
        end
      
        # Drop tables
        executeSQL("DROP TABLE #{namespace_binds}")
        executeSQL("DROP TABLE #{quoted_table}")
        executeSQL("DROP TABLE #{literal_table}")
        executeSQL("DROP TABLE #{asserted_type_table}")
        executeSQL("DROP TABLE #{asserted_table}")
      end

      protected

      # Where clase utility functions
      def buildSubjClause(subject, tableName)
        case subject
    #    when REGEXTerm
    #    when Array
        when Graph
           ["#{tableName}.subject=?", self.normalizeTerm(subject.identifier)]
        else
          ["#{tableName}.subject=?", subject] if subject
        end
      end

      def buildPredClause(predicate, tableName)
    #    case predicate
    #    when REGEXTerm
    #    when Array
    #    else
          ["#{tableName}.predicate=?", predicate] if predicate
    #    end
      end

      # Where clase utility functions
      def buildObjClause(object, tableName)
        case object
    #    when REGEXTerm
    #    when Array
      when Graph
        ["#{tableName}.object=?", self.normalizeTerm(object.identifier)]
        else
          ["#{tableName}.object=?", object] if object
        end
      end

      # Where clase utility functions
      def buildContextClause(context, tableName)
        context = normalizeTerm(context) if context

    #    case context
    #    when REGEXTerm
    #    when Array
    #    else
          ["#{tableName}.context=?", context] if context
    #    end
      end

      # Where clase utility functions
      def buildTypeMemberClause(subject, tableName)
    #    case context
    #    when REGEXTerm
    #    when Array
    #    else
          ["#{tableName}.member=?", subject] if subject
    #    end
      end

      # Where clase utility functions
      def buildTypeClassClause(object, tableName)
    #    case context
    #    when REGEXTerm
    #    else
          ["#{tableName}.klass=?", object] if object
    #    end
      end

      # This takes the query string and parameters and (depending on the SQL implementation) either fill in
      # the parameter in-place or pass it on to the DB impl (if it supports this).
      # The default (here) is to fill the parameters in-place surrounding each param with quote characters
      #
      # Yields each row
      def executeSQL(qStr, *params, &block)
        conn = ActiveRecord::Base.connection
      
        puts "executeSQL: params=#{params.flatten.inspect}" if ::RdfContext::debug?
        puts "executeSQL: '#{params.dup.unshift(qStr).join("', '")}'" if ::RdfContext::debug?
        qStr = ActiveRecord::Base.send(:replace_bind_variables, qStr, params.flatten)
        puts "  => '#{qStr}'" if ::RdfContext::debug?

        if block_given?
          conn.select_rows(qStr).each do |row|
            yield(row)
          end
        else
          puts "executeSQL no block given" if ::RdfContext::debug?
          conn.select_rows(qStr)
        end
      rescue StandardError => e
        puts "SQL Exception (ignored): #{e.message}" if ::RdfContext::debug?
      end

      CREATE_ASSERTED_STATEMENTS_TABLE = %(
      CREATE TABLE %s_asserted_statements (
          subject       text not NULL,
          predicate     text not NULL,
          object        text not NULL,
          context       text not NULL,
          termComb      tinyint unsigned not NULL))

      CREATE_ASSERTED_TYPE_STATEMENTS_TABLE = %(
      CREATE TABLE %s_type_statements (
          member        text not NULL,
          klass         text not NULL,
          context       text not NULL,
          termComb      tinyint unsigned not NULL))

      CREATE_LITERAL_STATEMENTS_TABLE = %(
      CREATE TABLE %s_literal_statements (
          subject       text not NULL,
          predicate     text not NULL,
          object        text,
          context       text not NULL,
          termComb      tinyint unsigned not NULL,
          objLanguage   varchar(3),
          objDatatype   text))

      CREATE_QUOTED_STATEMENTS_TABLE = %(
      CREATE TABLE %s_quoted_statements (
          subject       text not NULL,
          predicate     text not NULL,
          object        text,
          context       text not NULL,
          termComb      tinyint unsigned not NULL,
          objLanguage   varchar(3),
          objDatatype   text))

      CREATE_NS_BINDS_TABLE = %(
      CREATE TABLE %s_namespace_binds (
          prefix        varchar(20) UNIQUE not NULL,
          uri           text,
          PRIMARY KEY (prefix)))

      DROP_ASSERTED_STATEMENTS_TABLE = %(DROP TABLE %s_asserted_statements)
      DROP_ASSERTED_TYPE_STATEMENTS_TABLE = %(DROP TABLE %s_type_statements)
      DROP_LITERAL_STATEMENTS_TABLE = %(DROP TABLE %s_literal_statements)
      DROP_QUOTED_STATEMENTS_TABLE = %(DROP TABLE %s_quoted_statements)
      DROP_NS_BINDS_TABLE = %(DROP TABLE %s_namespace_binds)
    end
  end
end