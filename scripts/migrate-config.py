#!/usr/bin/python3
import base64
import json
import sys
import xml.etree.ElementTree as ET


def iterate_search_and_replace(config_dict, xml_tree):
    # Create iterable loop for search and replace
    s_and_r = {}
    for group in config_dict:
        if 'example' == group:
            continue
        s_and_r.update({group: {'tag': '', 'xml_string': '', 'plugins': [], 'search': {}, 'replace': {}}})
        for key, value in config_dict[group].items():
            task = None
            if '_search' in key.lower():
                name = key.split("_search")[0]
                task = 'search'
            if '_replace' in key.lower():
                name = key.split("_replace")[0]
                task = 'replace'
            if task is not None:
                s_and_r[group][task][name] = value
            if 'tag' == key:
                s_and_r[group]['tag'] = value
            if 'xml_string' == key:
                s_and_r[group]['xml_string'] = value
            if 'plugins' == key:
                for plugin in config_dict[group]['plugins']:
                    s_and_r[group]['plugins'].append(plugin)

    for group in s_and_r.keys():
        xml_object = tree.findall(s_and_r[group]['xml_string'])
        tag = s_and_r[group]['tag']
        for xml_value in xml_object:
            if tag is not None:
                if xml_value.tag != tag:
                    continue
            for search_key in s_and_r[group]['search'].keys():
                search_value = s_and_r[group]['search'][search_key]
                filtered_output = plugin_filter(xml_value.text, s_and_r[group]['plugins'], 'decode')
                if search_value in filtered_output:
                    search_output = filtered_output.replace(search_value, s_and_r[group]['replace'][search_key])
                    xml_value.text = plugin_filter(search_output, s_and_r[group]['plugins'], 'encode')
    return xml_tree


def plugin_filter(text, plugins, direction):
    # This parses the text through the plugins in ORDER
    for plugin in plugins:
        if plugin is None:
            return text
        if 'base64' in plugin:
            return base64_parse(text, direction)


def base64_parse(text, direction):
    message = text.encode('utf-8')
    if 'encode' == direction:
        new_base64_bytes = base64.b64encode(message)
        return new_base64_bytes.decode('utf-8')
    if 'decode' == direction:
        old_message_bytes = base64.b64decode(message)
        return old_message_bytes.decode('utf-8')


print("use as python3 migrate-config.py FULL-path-to-virtualhome-config-xml")
print("Will output to the same filename with the appended extension '.new'")

migration_config = {}
with open("../resources/network-config.json", "r") as json_file:
    migration_config = json.load(json_file)

# Update Core Values
tree = ET.parse(sys.argv[1])
tree = iterate_search_and_replace(migration_config['search_and_replace'], tree)
tree.write(sys.argv[1] + '.new')
print("check " + sys.argv[1] + ".new for your updated config!")
