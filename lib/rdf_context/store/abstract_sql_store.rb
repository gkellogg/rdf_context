require File.join(File.dirname(__FILE__), 'abstract_store')
require 'digest/sha1'

module RdfContext
  # SQL-92 formula-aware implementation of an RDF Store.
  # It stores it's triples in the following partitions:
  # - Asserted non rdf:type statements
  # - Asserted literal statements
  # - Asserted rdf:type statements (in a table which models Class membership). The motivation for this partition is primarily query speed and scalability as most graphs will always have more rdf:type statements than others
  # - All Quoted statements
  #
  #  In addition it persists namespace mappings in a seperate table
  #
  # Based on Python RdfLib AbstractSQLStore
  class AbstractSQLStore < AbstractStore
    include TermUtils
    
    COUNT_SELECT   = 0
    CONTEXT_SELECT = 1
    TRIPLE_SELECT  = 2
    TRIPLE_SELECT_NO_ORDER = 3

    ASSERTED_NON_TYPE_PARTITION = 3
    ASSERTED_TYPE_PARTITION     = 4
    QUOTED_PARTITION            = 5
    ASSERTED_LITERAL_PARTITION  = 6

    FULL_TRIPLE_PARTITIONS = [QUOTED_PARTITION,ASSERTED_LITERAL_PARTITION]

    INTERNED_PREFIX = 'kb_'
    
    STRONGLY_TYPED_TERMS = false
    
    # @param[URIRef] identifier:: URIRef of the Store. Defaults to CWD
    # @param[Hash] configuration:: Hash containing infomation open can use to connect to datastore.
    def initialize(identifier = nil, configuration = {})
      @literalCache = {}
      @otherCache = {}
      @bnodeCache = {}
      @uriCache = {}
      
      @autocommit_default = true
      
      raise StoreException.new("Identifier must be nil or a URIRef") if identifier && !identifier.is_a?(URIRef)
      @identifier = identifier || URIRef.new("file:/#{Dir.getwd}")
      
      @internedId = INTERNED_PREFIX + Digest::SHA1.hexdigest(@identifier.to_s)[0..9] # Only first 10 bytes of digeset
      
      @db = configuration.empty? ? nil : open(configuration)
    end

    # Supports contexts
    def context_aware?; true; end
    
    # Supports formulae
    def formula_aware?; true; end

    # Supports transactions
    def transaction_aware?; true; end
    
    def close(commit_pending_transactions = false)
      @db.commit if commit_pending_transactions && @db.transaction_active?
      @db.close
    end
    
    # Add a triple to the store
    # Add to default context, if context is nil
    def add(triple, context = nil, quoted = false)
      context ||= @identifier
      executeSQL("SET AUTOCOMMIT=0") if @autocommit_default
      
      if quoted || triple.predicate != RDF_TYPE
        # Quoted statement or non rdf:type predicate
        # Check if object is a literal
        if triple.object.is_a?(Literal)
          addCmd, *params = self.buildLiteralTripleSQLCommand(triple, context)
        else
          addCmd, *params = self.buildTripleSQLCommand(triple, context, quoted)
        end
      elsif triple.predicate == RDF_TYPE
        addCmd, *params = self.buildTypeSQLCommand(triple.subject, triple.object, context)
      end
      
      executeSQL(addCmd, params)
    end
    
    # Remove a triple from the context and store
    #
    # if subject, predicate and object are nil and context is not nil, the context is removed
    def remove(triple, context = nil)
      if context
        if triple.subject == nil && triple.predicate.nil? && triple.object.nil?
          return remove_context(context)
        end
      end
      
      if triple.predicate.nil? || triple.predicate != RDF_TYPE
        # Remove predicates other than rdf:type
        if !STRONGLY_TYPED_TERMS || triple.object.is_a?(Literal)
          clauseString, *params = self.buildClause(literal_table,triple,context)
          if !clauseString.empty?
            cmd = "DELETE FROM #{literal_table} #{clauseString}"
          else
            cmd = "DELETE FROM #{literal_table}"
          end
          executeSQL(_normalizeSQLCmd(cmd), params)
        end
        
        [quoted_table, asserted_table].each do |table|
          # If asserted non rdf:type table and obj is Literal, don't do anything (already taken care of)
          next if table == asserted_table && triple.object.is_a?(Literal)
          
          clauseString, *params = self.buildClause(table, triple, context)
          if !clauseString.empty?
            cmd = "DELETE FROM #{table} #{clauseString}"
          else
            cmd = "DELETE FROM #{table}"
          end
          executeSQL(_normalizeSQLCmd(cmd), params)
        end
      elsif triple.predicate == RDF_TYPE || triple.predicate.nil?
        # Need to check rdf:type and quoted partitions (in addition perhaps)
        clauseString, *params = self.buildClause(asserted_type_table,triple,context, true)
        if !clauseString.empty?
          cmd = "DELETE FROM #{asserted_type_table} #{clauseString}"
        else
          cmd = "DELETE FROM #{asserted_type_table}"
        end
        executeSQL(_normalizeSQLCmd(cmd), params)

        clauseString, *params = self.buildClause(quoted_table,triple,context)
        if !clauseString.empty?
          cmd = "DELETE FROM #{quoted_table} #{clauseString}"
        else
          cmd = "DELETE FROM #{quoted_table}"
        end
        executeSQL(_normalizeSQLCmd(cmd), params)
      end
    end
    
    # A generator over all the triples matching pattern.
    # 
    # quoted table::                <id>_quoted_statements
    # asserted rdf:type table::     <id>_type_statements
    # asserted non rdf:type table:: <id>_asserted_statements
    # 
    # triple columns: subject,predicate,object,context,termComb,objLanguage,objDatatype
    # class membership columns: member,klass,context termComb
    # 
    # FIXME:  These union all selects *may* be further optimized by joins
    def triples(triple, context = nil)  # :yields: triple, context
      parameters = []
      
      if triple.predicate == RDF_TYPE
        # select from asserted rdf:type partition and quoted table (if a context is specified)
        clauseString, *params = self.buildClause('typeTable',triple,context, true)
        parameters += params
        selects = [
          [
            asserted_type_table,
            'typeTable',
            clauseString,
            ASSERTED_TYPE_PARTITION
          ],
        ]
      # elsif triple.predicate.is_a?(REGEXTerm) && triple.predicate.compiledExpr.match(RDF_TYPE) || triple.predicate.nil?
      elsif triple.predicate.nil?
        # Select from quoted partition (if context is specified), literal partition if (obj is Literal or None) and asserted non rdf:type partition (if obj is URIRef or None)
        selects = []
        if !STRONGLY_TYPED_TERMS || triple.object.is_a?(Literal) || triple.object.nil?
          clauseString, *params = self.buildClause('literal',triple,context)
          parameters += params
          selects += [
            [
              literal_table,
              'literal',
              clauseString,
              ASSERTED_LITERAL_PARTITION
            ]
          ]
        end
      
        if !triple.object.is_a?(Literal) || triple.object.nil?
          clauseString, *params = self.buildClause('asserted',triple,context)
          parameters += params
          selects += [
            [
              asserted_table,
              'asserted',
              clauseString,
              ASSERTED_NON_TYPE_PARTITION
            ]
          ]
        end

        clauseString, *params = self.buildClause('typeTable',Triple.new(triple.subject, RDF_TYPE, triple.object),context, true)
        parameters += params
        selects += [
          [
            asserted_type_table,
            'typeTable',
            clauseString,
            ASSERTED_TYPE_PARTITION
          ]
        ]
      elsif triple.predicate
        # select from asserted non rdf:type partition (optionally), quoted partition (if context is speciied), and literal partition (optionally)
        selects = []
        if !STRONGLY_TYPED_TERMS || triple.object.is_a?(Literal) || triple.object.nil?
          clauseString, *params = self.buildClause('literal',triple,context)
          parameters += params
          selects += [
            [
              literal_table,
              'literal',
              clauseString,
              ASSERTED_LITERAL_PARTITION
            ]
          ]
        end
    
        if !triple.object.is_a?(Literal) || triple.object.nil?
          clauseString, *params = self.buildClause('asserted',triple,context)
          parameters += params
          selects += [
            [
              asserted_table,
              'asserted',
              clauseString,
              ASSERTED_NON_TYPE_PARTITION
            ]
          ]
        end
      end
      
      if context
        clauseString, *params = self.buildClause('quoted',triple,context)
        parameters += params
        selects += [
          [
            quoted_table,
            'quoted',
            clauseString,
            QUOTED_PARTITION
          ]
        ]
      end
      
      q = _normalizeSQLCmd(unionSELECT(selects))
      results = []
      executeSQL(q, parameters) do |row|
        triple, graphKlass, idKlass, graphId = extractTriple(row, context)
        currentContext = graphKlass.new(:store => self, :identifier => idKlass.new(graphId))
        if block_given?
          yield(triple, currentContext)
        else
          results << triple
        end
      end
      
      results.uniq
    end
    
    def contains?(triple, context = nil)
      #puts "contains? #{triple}"
      object = triple.object
      if object.is_a?(Literal)
        triple = Triple.new(triple.subject, triple.predicate, nil)
        triples(triple, context) do |t, cg|
          return true if t.object == object
        end
        false
      else
        !triples(triple, context).empty?
      end
    end
    
    # Number of statements in the store.
    def size(context = nil)
      parameters = []
      quotedContext = assertedContext = typeContext = literalContext = nil

      clauseParts = self.buildContextClause(context,quoted_table)
      if clauseParts
        quotedContext = clauseParts.shift
        parameters += clauseParts
      end

      clauseParts = self.buildContextClause(context,asserted_table)
      if clauseParts
        assertedContext = clauseParts.shift
        parameters += clauseParts
      end

      clauseParts = self.buildContextClause(context,asserted_type_table)
      if clauseParts
        typeContext = clauseParts.shift
        parameters += clauseParts
      end

      clauseParts = self.buildContextClause(context,literal_table)
      if clauseParts
        literalContext = clauseParts.shift
        parameters += clauseParts
      end

      if context
        selects = [
          [
            asserted_type_table,
            'typeTable',
            typeContext ? 'where ' + typeContext : '',
            ASSERTED_TYPE_PARTITION
          ],
          [
            quoted_table,
            'quoted',
            quotedContext ? 'where ' + quotedContext : '',
            QUOTED_PARTITION
          ],
          [
            asserted_table,
            'asserted',
            assertedContext ? 'where ' + assertedContext : '',
            ASSERTED_NON_TYPE_PARTITION
          ],
          [
            literal_table,
            'literal',
            literalContext ? 'where ' + literalContext : '',
            ASSERTED_LITERAL_PARTITION
          ],
        ]
        q=unionSELECT(selects, :distinct => true, :select_type => COUNT_SELECT)
      else
        selects = [
          [
            asserted_type_table,
            'typeTable',
            typeContext ? 'where ' + typeContext : '',
            ASSERTED_TYPE_PARTITION
          ],
          [
            asserted_table,
            'asserted',
            assertedContext ? 'where ' + assertedContext : '',
            ASSERTED_NON_TYPE_PARTITION
          ],
          [
            literal_table,
            'literal',
            literalContext ? 'where ' + literalContext : '',
            ASSERTED_LITERAL_PARTITION
          ],
        ]
        q=unionSELECT(selects, :select_type => COUNT_SELECT)
      end

      count = 0
      executeSQL(self._normalizeSQLCmd(q), parameters) do |row|
        count += row[0].to_i
      end
      count
    end

    # Contexts containing the triple (no matching), or total number of contexts in store
    def contexts(triple = nil)
      parameters = []
      
      if triple
        subject, predicate, object = triple.subject, triple.predicate, triple.object
        if predicate == RDF_TYPE
          # select from asserted rdf:type partition and quoted table (if a context is specified)
          clauseString, *params = self.buildClause('typeTable',triple,nil, true)
          parameters += params
          selects = [
            [
              asserted_type_table,
              'typeTable',
              clauseString,
              ASSERTED_TYPE_PARTITION
            ],
          ]
        #elsif predicate.is_a?(REGEXTerm) && predicate.compiledExpr.match(RDF_TYPE) || predicate.nil?
        elsif predicate.nil?
          # Select from quoted partition (if context is specified), literal partition if (obj is Literal or None) and asserted non rdf:type partition (if obj is URIRef or None)
          clauseString, *params = self.buildClause('typeTable',Triple.new(subject, RDF_TYPE, object),nil, true)
          parameters += params
          selects = [
            [
              asserted_type_table,
              'typeTable',
              clauseString,
              ASSERTED_TYPE_PARTITION
            ],
          ]

          if !STRONGLY_TYPED_TERMS || triple.object.is_a?(Literal) || triple.object.nil?
            clauseString, *params = self.buildClause('literal',triple)
            parameters += params
            selects += [
              [
                literal_table,
                'literal',
                clauseString,
                ASSERTED_LITERAL_PARTITION
              ]
            ]
          end
          if !object.is_a?(Literal) || object.nil?
            clauseString, *params = self.buildClause('asserted',triple)
            parameters += params
            selects += [
              [
                asserted_table,
                'asserted',
                clauseString,
                ASSERTED_NON_TYPE_PARTITION
              ]
            ]
          end
        elsif predicate
          # select from asserted non rdf:type partition (optionally), quoted partition (if context is speciied), and literal partition (optionally)
          selects = []
          if !STRONGLY_TYPED_TERMS || object.is_a?(Literal) || object.nil?
            clauseString, *params = self.buildClause('literal',triple)
            parameters += params
            selects += [
              [
                literal_table,
                'literal',
                clauseString,
                ASSERTED_LITERAL_PARTITION
              ]
            ]
          end
          if !object.is_a?(Literal) || object.nil?
            clauseString, *params = self.buildClause('asserted',triple)
            parameters += params
            selects += [
              [
                asserted_table,
                'asserted',
                clauseString,
                ASSERTED_NON_TYPE_PARTITION
              ]
            ]
          end
        end

        clauseString, *params = self.buildClause('quoted',triple)
        parameters += params
        selects += [
          [
            quoted_table,
            'quoted',
            clauseString,
            QUOTED_PARTITION
          ]
        ]
      else
        selects = [
          [
            asserted_type_table,
            'typeTable',
            '',
            ASSERTED_TYPE_PARTITION
          ],
          [
            quoted_table,
            'quoted',
            '',
            QUOTED_PARTITION
          ],
          [
            asserted_table,
            'asserted',
            '',
            ASSERTED_NON_TYPE_PARTITION
          ],
          [
            literal_table,
            'literal',
            '',
            ASSERTED_LITERAL_PARTITION
          ],
        ]
      end

      q=unionSELECT(selects, :distinct => true, :select_type => CONTEXT_SELECT)
      executeSQL(_normalizeSQLCmd(q), parameters).map do |row|
        id, termComb = row

        termCombString = REVERSE_TERM_COMBINATIONS[termComb.to_i]
        subjTerm, predTerm, objTerm, ctxTerm = termCombString.scan(/./)

        graphKlass, idKlass = constructGraph(ctxTerm)
        [graphKlass, idKlass.new(id)]
      end.uniq.map do |gi|
        graphKlass, id = gi
        graphKlass.new(:store => self, :identifier => id)
      end
    end
    
    # Namespace persistence interface implementation
    #
    # Bind namespace to store, returns bound namespace
    def bind(namespace)
      executeSQL("INSERT INTO #{namespace_binds} VALUES (?, ?)", namespace.prefix, namespace.uri)
      # May throw exception, should be handled in driver-specific class

      @namespaceCache ||= {}
      @namespaceUriCache ||= {}
      @nsbinding = nil
      @uri_binding = nil
      @namespaceCache[namespace.prefix] = namespace
      @namespaceUriCache[namespace.uri.to_s] = namespace.prefix
      namespace
    end

    # Namespace for prefix
    def namespace(prefix)
      @namespaceCache ||= {}
      @namespaceUriCache ||= {}
      unless @namespaceCache.has_key?(prefix.to_s)
        @namespaceCache[prefix] = nil
        executeSQL("SELECT uri FROM #{namespace_binds} WHERE prefix=?", prefix.to_s) do |row|
          @namespaceCache[prefix.to_s] = Namespace.new(row[0], prefix.to_s)
          @namespaceUriCache[row[0].to_s] = prefix.to_s
        end
      end
      @namespaceCache[prefix.to_s]
    end
    
    # Prefix for namespace
    def prefix(namespace)
      uri = namespace.is_a?(Namespace) ? namespace.uri.to_s : namespace

      @namespaceCache ||= {}
      @namespaceUriCache ||= {}
      unless @namespaceUriCache.has_key?(uri.to_s)
        @namespaceUriCache[uri.to_s] = nil
        executeSQL("SELECT prefix FROM #{namespace_binds} WHERE uri=?", uri) do |row|
          @namespaceUriCache[uri.to_s] = row[0]
        end
      end
      @namespaceUriCache[uri.to_s]
    end

    # Hash of prefix => Namespace bindings
    def nsbinding
      unless @nsbinding.is_a?(Hash)
        @nsbinding = {}
        @uri_binding = {}
        executeSQL("SELECT prefix, uri FROM #{namespace_binds}") do |row|
          prefix, uri = row
          namespace = Namespace.new(uri, prefix)
          @nsbinding[prefix] = namespace
          # Over-write an empty prefix
          @uri_binding[uri] = namespace unless prefix.to_s.empty?
          @uri_binding[uri] ||= namespace
        end
        @nsbinding
      end
      @nsbinding
    end
    
    # Hash of uri => Namespace bindings
    def uri_binding
      nsbinding
      @uri_binding
    end
    
    # Transactional interfaces
    def commit; @db.commit; end

    def rollback; @db.rollback; end

    protected
    def quoted_table; "#{@internedId}_quoted_statements"; end
    def asserted_table; "#{@internedId}_asserted_statements"; end
    def asserted_type_table; "#{@internedId}_type_statements"; end
    def literal_table; "#{@internedId}_literal_statements"; end
    def namespace_binds; "#{@internedId}_namespace_binds"; end
    
    def remove_context(identifier)
      executeSQL("SET AUTOCOMMIT=0") if @autocommit_default
      
      %w(quoted asserted type literal)
      [quoted_table,asserted_table,asserted_type_table,literal_table].each do |table|
        clauseString, *params = self.buildContextClause(identifier,table)
        executeSQL(
            _normalizeSQLCmd("DELETE from #{table} where #{clauseString}"),
            params
        )
      end
    end
    
    # This takes the query string and parameters and (depending on the SQL implementation) either fill in
    # the parameter in-place or pass it on to the DB impl (if it supports this).
    # The default (here) is to fill the parameters in-place surrounding each param with quote characters
    #
    # Yields each row
    def executeSQL(qStr, *params, &block)
      @db.execute(qStr, *params, &block)
    end
    
    # Normalize a SQL command before executing it.  Commence unicode black magic
    def _normalizeSQLCmd(cmd)
      cmd # XXX
    end
    
    #T akes a term and 'normalizes' it.
    # Literals are escaped, Graphs are replaced with just their identifiers
    def normalizeTerm(term)
      case term
      when Graph    then normalizeTerm(term.identifier)
      when Literal  then term.to_s.rdf_escape
      when URIRef   then term.to_s.rdf_escape
      when BNode    then term.to_s
      else               term
      end
    end
    
    # Builds an insert command for a type table
    # Returns string and list of parameters
    def buildTypeSQLCommand(member,klass,context)
      [
        "INSERT INTO #{asserted_type_table} VALUES (?, ?, ?, ?)",
        normalizeTerm(member),
        normalizeTerm(klass),
        normalizeTerm(context),
        type2TermCombination(member, klass, context)
      ]
    end
    
    # Builds an insert command for literal triples (statements where the object is a Literal)
    # Returns string and list of parameters
    def buildLiteralTripleSQLCommand(triple,context)
      triplePattern = statement2TermCombination(triple,context)
      [
        "INSERT INTO #{literal_table} VALUES (?, ?, ?, ?, ?,?,?)",
        normalizeTerm(triple.subject),
        normalizeTerm(triple.predicate),
        normalizeTerm(triple.object),
        normalizeTerm(context),
        triplePattern,
        (triple.object.is_a?(Literal) ? triple.object.lang : NULL),
        (triple.object.is_a?(Literal) ? triple.object.encoding.value.to_s : NULL),
      ]
    end
    
    # Builds an insert command for regular triple table
    def buildTripleSQLCommand(triple,context,quoted)
      stmt_table = quoted ? quoted_table : asserted_table
      triplePattern = statement2TermCombination(triple,context)

      if quoted
        [
          "INSERT INTO #{stmt_table} VALUES (?, ?, ?, ?, ?,?,?)",
          normalizeTerm(triple.subject),
          normalizeTerm(triple.predicate),
          normalizeTerm(triple.object),
          normalizeTerm(context),
          triplePattern,
          (triple.object.is_a?(Literal) ? triple.object.lang : NULL),
          (triple.object.is_a?(Literal) ? triple.object.encoding.value.to_s : NULL),
        ]
      else
        [
          "INSERT INTO #{stmt_table} VALUES (?, ?, ?, ?, ?)",
          normalizeTerm(triple.subject),
          normalizeTerm(triple.predicate),
          normalizeTerm(triple.object),
          normalizeTerm(context),
          triplePattern
        ]
      end
    end
    
    # Builds WHERE clauses for the supplied terms and, context
    def buildClause(tableName,triple,context=nil,typeTable=false)
      parameters=[]
      if typeTable
        rdf_type_memberClause = rdf_type_klassClause = rdf_type_contextClause = nil

        # Subject clause
        clauseParts = self.buildTypeMemberClause(self.normalizeTerm(triple.subject),tableName)
        if clauseParts
          rdf_type_memberClause = clauseParts.shift
          parameters += clauseParts
        end

        # Object clause
        clauseParts = self.buildTypeClassClause(self.normalizeTerm(triple.object),tableName)
        if clauseParts
          rdf_type_klassClause = clauseParts.shift
          parameters += clauseParts
        end

        # Context clause
        clauseParts = self.buildContextClause(context,tableName)
        if clauseParts
          rdf_type_contextClause = clauseParts.shift
          parameters += clauseParts
        end

        clauses = [rdf_type_memberClause,rdf_type_klassClause,rdf_type_contextClause].compact
      else
        subjClause = predClause = objClause = contextClause = litDTypeClause = litLanguageClause = nil

        # Subject clause
        clauseParts = self.buildSubjClause(self.normalizeTerm(triple.subject),tableName)
        if clauseParts
          subjClause = clauseParts.shift
          parameters += clauseParts
        end

        # Predicate clause
        clauseParts = self.buildPredClause(self.normalizeTerm(triple.predicate),tableName)
        if clauseParts
          predClause = clauseParts.shift
          parameters += clauseParts
        end

        # Object clause
        clauseParts = self.buildObjClause(self.normalizeTerm(triple.object),tableName)
        if clauseParts
          objClause = clauseParts.shift
          parameters += clauseParts
        end

        # Context clause
        clauseParts = self.buildContextClause(context,tableName)
        if clauseParts
          contextClause = clauseParts.shift
          parameters += clauseParts
        end

        # Datatype clause
        clauseParts = self.buildLitDTypeClause(triple.object,tableName)
        if clauseParts
          litDTypeClause = clauseParts.shift
          parameters += clauseParts
        end

        # Language clause
        clauseParts = self.buildLitLanguageClause(triple.object,tableName)
        if clauseParts
          litLanguageClause = clauseParts.shift
          parameters += clauseParts
        end
        
        clauses = [subjClause,predClause,objClause,contextClause,litDTypeClause,litLanguageClause].compact
      end

      clauseString = clauses.join(' and ')
      clauseString = "WHERE #{clauseString}" unless clauseString.empty?
      
      [clauseString] + parameters
    end

    def buildLitDTypeClause(obj,tableName)
      ["#{tableName}.objDatatype='#{obj.encoding.value}'"] if obj.is_a?(Literal) && obj.encoding
    end
    
    def buildLitLanguageClause(obj,tableName)
      ["#{tableName}.objLanguage='#{obj.lang}'"] if obj.is_a?(Literal) && obj.lang
    end

    # Stubs for Clause Functions that are overridden by specific implementations (MySQL vs SQLite for instance)
    def buildSubjClause(subject,tableName); end
    def buildPredClause(predicate,tableName); end
    def buildObjClause(obj,tableName); end
    def buildContextClause(context,tableName); end
    def buildTypeMemberClause(subject,tableName); end
    def buildTypeClassClause(obj,tableName); end

    # Helper function for executing EXPLAIN on all dispatched SQL statements - for the pupose of analyzing
    # index usage
    def queryAnalysis(query)
    end
    
    # Helper function for building union all select statement
    # @param [Array] select_components:: list of [table_name, table_alias, table_type, where_clause]
    # @param [Hash] options:: Options
    # <em>options[:distinct]</em>:: true or false
    # <em>options[:select_type]</em>:: Defaults to TRIPLE_SELECT
    def unionSELECT(selectComponents, options = {})
      selectType = options[:select_type] || TRIPLE_SELECT
      selects = []
      
      selectComponents.each do |sc|
        tableName, tableAlias, whereClause, tableType = sc

        case
        when selectType == COUNT_SELECT
          selectString = "select count(*)"
          tableSource = " from #{tableName} "
        when selectType == CONTEXT_SELECT
          selectString = "select #{tableAlias}.context, " + 
                                "#{tableAlias}.termComb as termComb "
          tableSource = " from #{tableName} as #{tableAlias} "
        when FULL_TRIPLE_PARTITIONS.include?(tableType)
          selectString = "select *"
          tableSource = " from #{tableName} as #{tableAlias} "
        when tableType == ASSERTED_TYPE_PARTITION
          selectString = "select #{tableAlias}.member as subject, " +
                                "\"#{RDF_TYPE}\" as predicate, " + 
                                "#{tableAlias}.klass as object, " + 
                                "#{tableAlias}.context as context, " + 
                                "#{tableAlias}.termComb as termComb, " + 
                                "NULL as objLanguage, " + 
                                "NULL as objDatatype"
          tableSource = " from #{tableName} as #{tableAlias} "
        when tableType == ASSERTED_NON_TYPE_PARTITION
          selectString = "select *, NULL as objLanguage, NULL as objDatatype"
          tableSource = " from #{tableName} as #{tableAlias} "
        else
          raise StoreException, "unionSELECT failed to find template: selectType = #{selectType}, tableType = #{tableType}"
        end
        
        selects << "#{selectString}#{tableSource}#{whereClause}"
      end
      
      orderStmt = selectType == TRIPLE_SELECT ? " order by subject, predicate, object" : ""
      
      selects.join(options[:distinct] ? " union all ": " union ") + orderStmt
    end
    
    # Takes a tuple which represents an entry in a result set and
    # converts it to a tuple of terms using the termComb integer
    # to interpret how to instanciate each term
    # tupleRt is an array containing one or more of:
    # - subject
    # - predicate
    # - obj
    # - rtContext
    # - termComb
    # - objLanguage
    # - objDatatype
    def extractTriple(tupleRt, hardCodedContext = nil)
      subject, predicate, obj, rtContext, termComb, objLanguage, objDatatype = tupleRt

      raise StoreException, "extractTriple: unknow termComb: '#{termComb}'" unless REVERSE_TERM_COMBINATIONS.has_key?(termComb.to_i)

      context = rtContext || hardCodedContext
      termCombString = REVERSE_TERM_COMBINATIONS[termComb.to_i]
      subjTerm, predTerm, objTerm, ctxTerm = termCombString.scan(/./)
      
      s = createTerm(subject, subjTerm)
      p = createTerm(predicate, predTerm)
      o = createTerm(obj, objTerm, objLanguage, objDatatype)

      graphKlass, idKlass = constructGraph(ctxTerm)
      return [Triple.new(s, p, o), graphKlass, idKlass, context]
    end
    
    # Takes a term value, and term type
    # and Creates a term object.  QuotedGraphs are instantiated differently
    def createTerm(termString,termType,objLanguage=nil,objDatatype=nil)
      case termType
      when "L"
        @literalCache[[termString, objLanguage, objDatatype]] ||= Literal.n3_encoded(termString, objLanguage, objDatatype)
      when "F"
        @otherCache[[termType, termString]] ||= QuotedGraph(:identifier => URIRef(termString), :store => self)
      when "B"
        @bnodeCache[termString] ||= begin
          bn = BNode.new
          bn.identifier = termString
          bn
        end
      when "U"
        @uriCache[termString] || URIRef.new(termString)
#      when "V"
      else
        raise StoreException.new("Unknown termType: #{termType}")
      end
    end
  end
end