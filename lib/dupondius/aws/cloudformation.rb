
module Dupondius; module Aws; module CloudFormation

  ENVIRONMENTS = [:ci, :dev, :canary, :qa, :staging, :production]

  def self.access
    @cfn ||= AWS::CloudFormation.new(:access_key_id => Dupondius.config.access_key,
       :secret_access_key => Dupondius.config.secret_access_key)
  end

  def self.summaries project_name= Dupondius.config.project_name, status = :create_complete
    Dupondius::Aws::CloudFormation.access.stack_summaries.with_status(status).select do |s|
      s if s[:stack_name] =~ /.*#{project_name}$/
    end
  end

  class Stack

    TEMPLATES = [
      {id: 1, name: 'Rails Single Instance', template: 'rails_single_instance'},
      {id: 2, name: 'Rails Single Instance with MySQL RDS Instance', template: 'rails_single_instance_with_rds'},
      {id: 3, name: 'Jenkins CI', template: 'ci'}
    ]


    def initialize subject
      @subject = subject
    end

    def method_missing(sym, *args, &block)
      @subject.send sym, *args, &block
    end

    def self.find stack_name
      stack = Dupondius::Aws::CloudFormation.access.stacks[stack_name]
      stack.exists? ? self.new(stack) : nil
    end

    def self.create template_name, environment_name, project_name, parameters
      Dupondius::Aws::CloudFormation.access.stacks.create("#{environment_name}-#{project_name}", load_template(template_name),
        :parameters => {HostedZone: Dupondius.config.hosted_zone,
                        ProjectName: project_name,
                        AwsAccessKey: Dupondius.config.access_key,
                        AwsSecretAccessKey: Dupondius.config.secret_access_key,
                        KeyName: Dupondius.config.key_name}.merge(parameters))
    end

    def self.validate_template id
      Dupondius::Aws::CloudFormation.access.validate_template(load_template(lookup_template_name(id)))
    end

    def self.template_params template_name
      Dupondius::Aws::CloudFormation.access.validate_template(load_template(template_name))[:parameters].collect { |p| p[:parameter_key] }
    end

    def self.load_template template_name
      File.open(File.expand_path(File.join( File.dirname(__FILE__), '..', 'aws', 'templates', "#{template_name}.template")), 'rb').read
    end

    def self.lookup_template_name id
      TEMPLATES.detect { |t| t[:id] = id }[:template]
    end

    def template_name
      self.description.match(/\w+$/).to_s
    end

    def update params
      super({template: Stack.load_template(template_name), parameters: self.parameters.merge(params)})
    end

    def complete?
      @subject.status == 'CREATE_COMPLETE'
    end

    def as_json options={}
      result = {}
      AWS.memoize do
        result = [:name, :description, :status, :creation_time, :last_updated_time,
         :description, :parameters].inject({}) do |result, attribute|
            result[attribute] = self.send(attribute)
            result
        end
        result[:resource_summaries] = self.resource_summaries.collect do |r|
          resource = [:resource_type, :logical_resource_id].inject({}) do |h, a|
            h[a] = r[a]
            h
          end
          if r[:resource_type] == 'AWS::EC2::Instance'
            resource[:status] = :running
          end
          resource
        end
      end
      result
    end
  end

  class ContinuousIntegration < Stack

    def self.create project_name, tech_stack, parameters
      super('jenkins-' + tech_stack, 'ci', project_name, parameters)
    end

    def self.find project_name
      super("ci-#{project_name}")
    end
  end


  class Dashboard < Stack

    def self.create project_name, parameters
      super('rails_single_instance', 'dashboard', project_name, parameters.merge(EnvironmentName: 'dashboard'))
    end

    def self.find project_name
      super("dashboard-#{project_name}")
    end

    def self.template_params
      super("rails_single_instance")
    end

    def self.load_json template_name
      template= super(template_name)
      JSON.parse(template)

      # inject the dashboard install script into the user-data
      user_data = template['Resources']['WebServer']['Properties']['UserData']['Fn::Base64']['Fn::Join'].last
      user_data.insert((user_data.size) -4, "curl -L https://s3.amazonaws.com/dupondius/config/install-dashboard | bash \n")
      JSON.pretty_generate(template)
    end
  end
end; end; end
