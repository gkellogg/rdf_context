require File.join(File.dirname(__FILE__), 'spec_helper')

require 'rdfa_helper'
require 'patron'

# Time to add your specs!
# http://rspec.info/
describe "RDFa parser" do
  before(:each) do
     @parser = RdfaParser.new

     # Don't load external profiles when testing
     basic_resp = mock("basic_resp")
     basic_resp.stub(:status).and_return(200)
     basic_resp.stub(:body).and_return(File.read(File.join(RDFA_DIR, "profiles", "basic.html")))

     foaf_resp = mock("foaf_resp")
     foaf_resp.stub(:status).and_return(200)
     foaf_resp.stub(:body).and_return(File.read(File.join(RDFA_DIR, "profiles", "foaf.html")))

     hcard_resp = mock("hcard_resp")
     hcard_resp.stub(:status).and_return(200)
     hcard_resp.stub(:body).and_return("HCARD")

     profile_resp = mock("profile_resp")
     profile_resp.stub(:status).and_return(200)
     profile_resp.stub(:body).and_return("PROFILE")

     xhv_resp = mock("xhv_resp")
     xhv_resp.stub(:status).and_return(200)
     xhv_resp.stub(:body).and_return(File.read(File.join(RDFA_DIR, "profiles", "xhv.html")))

     sess = mock("session")
     sess.stub(:base_url=)
     sess.stub(:timeout=)
     sess.stub(:get).with("http://www.w3.org/2007/08/pyRdfa/profiles/foaf").and_return(foaf_resp)
     sess.stub(:get).with("http://www.w3.org/2007/08/pyRdfa/profiles/basic").and_return(basic_resp)
     sess.stub(:get).with("http://www.w3.org/1999/xhtml/vocab").and_return(xhv_resp)
     sess.stub(:get).with("http://microformats.org/profiles/hcard").and_return(hcard_resp)
     sess.stub(:get).with("http://www.w3.org/2005/10/profile").and_return(profile_resp)
     Patron::Session.stub!(:new).and_return(sess)
   end
  
   it "should parse simple doc" do
    sampledoc = <<-EOF;
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
    <head>
    	<title>Test 0001</title>
    </head>
    <body>
    	<p>This photo was taken by <span class="author" about="photo1.jpg" property="dc:creator">Mark Birbeck</span>.</p>
    </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0001.xhtml", :strict => true)
    @parser.graph.size.should == 1
    
    @parser.graph.to_rdfxml.should be_valid_xml
  end

  it "should parse simple doc without a base URI" do
    sampledoc = <<-EOF;
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
    <body>
    	<p>This photo was taken by <span class="author" about="_:photo" property="dc:creator">Mark Birbeck</span>.</p>
    </body>
    </html>
    EOF

    @parser.parse(sampledoc, nil, :strict => true)
    @parser.graph.size.should == 1
    
    @parser.graph.to_rdfxml.should be_valid_xml
  end

  it "should parse XML Literal and generate valid XML" do
    sampledoc = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
    	<head>
    		<title>Test 0011</title>
    	</head>
      <body>
      	<div about="">
          Author: <span property="dc:creator">Albert Einstein</span>
          <h2 property="dc:title">E = mc<sup>2</sup>: The Most Urgent Problem of Our Time</h2>
    	</div>
      </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    @parser.graph.size.should == 2
    
    xml = @parser.graph.to_rdfxml

    # Ensure that enclosed literal is also valid
    xml.should include("E = mc<sup xmlns=\"http://www.w3.org/1999/xhtml\">2</sup>: The Most Urgent Problem of Our Time")
  end


  it "should parse BNodes" do
    sampledoc = <<-EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml"
          xmlns:foaf="http://xmlns.com/foaf/0.1/">
      <head>
    	<title>Test 0017</title>   
      </head>
      <body>
      	 <p>
              <span about="[_:a]" property="foaf:name">Manu Sporny</span>
               <span about="[_:a]" rel="foaf:knows"
    resource="[_:b]">knows</span>
               <span about="[_:b]" property="foaf:name">Ralph Swick</span>.
            </p>
      </body>
    </html>
    EOF

    @parser.parse(sampledoc, "http://rdfa.digitalbazaar.com/test-suite/test-cases/xhtml1/0011.xhtml", :strict => true)
    @parser.graph.size.should == 3
    
    xml = @parser.graph.to_rdfxml
    xml.should be_valid_xml
    
    xml.should include("Ralph Swick")
    xml.should include("Manu Sporny")
  end
  
  def self.test_cases(suite)
    RdfaHelper::TestCase.test_cases(suite)
  end

  # W3C Test suite from http://www.w3.org/2006/07/SWD/RDFa/testsuite/
  %w(xhtml xhtml11).each do |suite| #html4 html5
    describe "w3c #{suite} testcases" do
      describe "that are approved" do
        test_cases(suite).each do |t|
          next unless t.status == "approved"
          #next unless t.name =~ /0140/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            #puts t.input
            #puts t.results
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [])
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            end
          end
        end
      end
      describe "that are unreviewed" do
        test_cases(suite).each do |t|
          next unless t.status == "unreviewed"
          #next unless t.name =~ /0185/
          #puts t.inspect
          specify "test #{t.name}: #{t.title}#{",  (negative test)" unless t.expectedResults}" do
            begin
              t.run_test do |rdfa_string, rdfa_parser|
                rdfa_parser.parse(rdfa_string, t.informationResourceInput, :debug => [])
              end
            rescue SparqlException => e
              pending(e.message) { raise }
            rescue Spec::Expectations::ExpectationNotMetError => e
              if t.name =~ /01[789]\d/
                raise
              else
                pending() {  raise }
              end
            end
          end
        end
      end
    end
  end
end