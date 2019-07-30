import json
import os

from jinja2 import Template
import yaml


CURRENT_PATH = os.getcwd()

def load_params(env):
  param_file = os.path.join(CURRENT_PATH, 'parameters', f'{env}.parameters.yml.j2')
  with open(param_file, 'r') as f:
    params = yaml.safe_load(f)
  return params


def load_templates(params):
  templates_to_load = [
    'vnet'
  ]
  rendered_templates = dict()
  for resource in templates_to_load:
    template_file = os.path.join(CURRENT_PATH, 'templates', f'{resource}.yml.j2')
    with open(template_file, 'r') as f:
      template = Template(f.read())
    rendered_templates[resource] = yaml.safe_load(template.render(params))
  return rendered_templates


def main():
  env = 'dv'
  params = load_params(env)

  rendered_templates = load_templates(params)
  template_data = {**params, **rendered_templates}
  
  deploy_template = os.path.join(CURRENT_PATH, 'deployments', 'azuredeploy.yml.j2')
  with open(deploy_template, 'r') as f:
    template = Template(f.read())
  
  final_deploy_definition = template.render(template_data)

  with open('FinalDeploy.json', 'w') as f:
    json.dump(yaml.safe_load(final_deploy_definition), f, indent=2)


if __name__ == '__main__':
  main()
