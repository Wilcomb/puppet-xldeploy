require 'puppet'
require 'rubygems'
require 'xmlsimple'
require 'rest_client'
require 'pathname'
require 'puppet/type/xldeploy_ci'

RSpec.configure {|config| config.mock_with :mocha }

describe 'The rest provider for the xldeploy_ci type' do
  id   = 'Infrastructure/TestHost'
  parent = 'Infrastructure'
  rest_url = "http://localhost:4516/deployit"
  type = 'overthere.SshHost'
  properties = {'host' => 'testhost', 'os' => 'UNIX', 'connectiontype' => 'SUDO', 'address' => '10.20.1.3', 'port' => '22', 'username' => 'xldeploy'}

  xml_response = '<overthere.SshHost id="Infrastructure/TestHost" token="760cfcf9-7988-4345-9045-e0d8ddda0679">
                  <tags />
                  <os>UNIX</os>
                  <connectionType>SUDO</connectionType>
                  <address>10.20.1.3</address>
                  <port>22</port>
                  <username>xldeploy</username>
                 </overthere.SshHost>'

  xml_invalid_response = '<overthere.SshHost id="Infrastructure/TestHost" token="760cfcf9-7988-4345-9045-e0d8ddda0679">
                          <tags />
                          <os>UNIX</os>
                          <connectionType>SUDO</connectionType>
                          <address>10.20.1.4</address>
                          <port>22</port>
                          <username>xldeploy</username>
                         </overthere.SshHost>'
  xml_inspection_response = '<inspection>
                                <inspectable>
                                    <overthere.SshHost id="Infrastructure/TestHost">
                                        <tags/>
                                        <deploymentGroup>0</deploymentGroup>
                                        <os>UNIX</os>
                                        <connectionType>SUDO</connectionType>
                                        <address>10.20.1.3</address>
                                        <port>22</port>
                                        <username>xldeploy</username>
                                        <privateKeyFile>/opt/deployit/deployit-server/.ssh/id_rsa</privateKeyFile>
                                        <passphrase>{b64}wEPzTb3gmRezwziWYs3m90pEJffCt7a+sGiIA3gujVm01Gdc4xmn71z4gZFsCqgyXgGDUzMqdkIyR6PiowA1iw==</passphrase>
                                    </overthere.SshHost>
                                </inspectable>
                            </inspection>'
  xml_task_state_running    = '<task id="bdf50933-0478-4217-9c13-2c8edea4edd4" currentStep="0" totalSteps="0" failures="0" state="EXECUTING" owner="admin">
                                    <description>Inspection of Infrastructure/TestHost</description>
                                    <startDate>2014-10-14T06:55:13.402+0000</startDate>
                                    <metadata>
                                        <taskType>INSPECTION</taskType>
                                    </metadata>
                                </task>'
  xml_task_state_executed    = '<task id="bdf50933-0478-4217-9c13-2c8edea4edd4" currentStep="0" totalSteps="0" failures="0" state="EXECUTED" owner="admin">
                                    <description>Inspection of Infrastructure/TestHost</description>
                                    <startDate>2014-10-14T06:55:13.402+0000</startDate>
                                    <metadata>
                                        <taskType>INSPECTION</taskType>
                                    </metadata>
                                </task>'
  inspection_id     = 'bdf50933-0478-4217-9c13-2c8edea4edd4'
  xml_true_response = '<boolean>true</boolean>'
  xml_false_response = '<boolean>false</boolean>'

  exists_url = 'repository/exists/Infrastructure/TestHost'
  exists_parent_url = 'repository/exists/Infrastructure'
  create_url = 'repository/ci/Infrastructure/TestHost'
  create_cis_url = 'repository/cis'
  inspection_prepare_url = 'inspection/prepare/'
  inspection_url = 'inspection/'
  inspection_retrieve_url ="inspection/retrieve/#{inspection_id}"
  start_task_url = "task/#{inspection_id}/start"
  check_task_url = "task/#{inspection_id}"
  archive_task_url = "task/#{inspection_id}/archive"

  let (:resource) { Puppet::Type::Xldeploy_ci.new({:id          => id,
                                                   :rest_url    => rest_url,
                                                   :type        => type,
                                                   :properties  => properties }) }

  let (:provider) { Puppet::Type.type(:xldeploy_ci).provider(:rest).new(resource) }



  it 'exists? should return true if repo exists' do
    provider.stubs(:execute_rest).with(exists_url,
                                'get').returns(xml_true_response)
    provider.exists?.should == true
  end
  it 'exists? should return false if repo doesnt exist' do
    provider.stubs(:execute_rest).with(exists_url,
                                       'get').returns(xml_false_response)
    provider.exists?.should == false
  end

  it 'create should try to determine if the parent ci for this ci exists' do
    xml_post = provider.to_xml(id, type, properties)
    provider.expects(:execute_rest).with(exists_parent_url, 'get').returns(xml_true_response)
    provider.expects(:execute_rest).with(create_url, 'post', xml_post).returns(xml_response)
    provider.create
  end

  it 'create with discovery set to true should try do run a discovery job on the xldeploy server' do

    resource[:discovery] = true
    xml_post = provider.to_xml(id, type, properties)

    provider.expects(:execute_rest).with(inspection_prepare_url, 'post', xml_post).returns(xml_inspection_response)
    provider.expects(:execute_rest).with(inspection_url, 'post', xml_inspection_response).returns(inspection_id)
    provider.expects(:execute_rest).with(start_task_url, 'post', '').returns
    provider.expects(:execute_rest).with(check_task_url, 'get').returns(xml_task_state_executed)
    provider.expects(:execute_rest).with(archive_task_url, 'post', '').returns()
    provider.expects(:execute_rest).with(inspection_retrieve_url, 'get').returns(xml_post)
    provider.expects(:execute_rest).with(exists_parent_url, 'get').returns(xml_true_response)
    provider.expects(:execute_rest).with(create_cis_url, 'post', xml_post).returns(xml_response)
    provider.create
  end


  it 'destroy should try to destroy the ci ' do
    xml_post = provider.to_xml(id, type, properties)
    provider.expects(:execute_rest).with(create_url, 'delete').returns(xml_true_response)
    provider.destroy
  end

  it 'should return the actual properties wich should not be equal to the properties given' do
    provider.expects(:execute_rest).with(create_url, 'get').returns(xml_invalid_response)
    provider.properties != properties
  end

  it 'should pass the correct xml to rest put when properties need amending' do
    xml_put = provider.to_xml(id, type, properties)
    provider.expects(:execute_rest).with(create_url,'put', xml_put).returns(xml_response)
    provider.properties= properties
  end
end