#!/usr/bin/python3

"""cli_args lookup plugin."""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.lookup import LookupBase

try:
    from ansible import context
except ImportError:
    context = False

DOCUMENTATION = """
    name: cli_args
    author: Glenn Marcy
    short_description: Lookup Ansible command-line arguments
    description: Retrieves the Ansible command-line arguments
"""

EXAMPLES = """
    - name: Show remote_user command line argument (-u | --user <username>)
      debug: msg="{{ lookup('cli_args')['remote_user'] }}"
"""

RETURN = """
_raw:
  description:
    - the arguments from the command-line
  type: raw
"""


class LookupModule(LookupBase):
    """Define LookupModule."""

    def run(self, terms, variables=None, **kwargs):
        """Define run function."""
        ret = []

        if context:
            ret.append(context.CLIARGS)

        return ret
