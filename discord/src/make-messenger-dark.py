import re
s=open('src/messenger.css').read()
m={'#ffffff':'#1f2228','#fff':'#1f2228','#000000':'#e6e9ee','#000':'#e6e9ee','#333333':'#cfd3da','#777777':'#9aa0a8',
'#d4e3f5':'#1c2a3d','#e3ecf8':'#18212d','#eef3fa':'#15191f','#cfddf4':'#1c2a3d','#fbfdff':'#2e3a4a','#eef4fb':'#273240',
'#e3ecf7':'#1f2834','#eaf1f9':'#232d3a','#e2eaf3':'#2c333d','#9db2cf':'#3b4a5e','#edf2fb':'#26354a','#d2eaf6':'#2b4a6a',
'#e4e4e4':'#30343a','#001563':'#cfe3ff','#b5c7de':'#334255','#dfe9f6':'#1e2836','#eaf1fa':'#222d3b','#e6eef8':'#253142',
'#a9bfdc':'#3b4a5e','#8fb0d8':'#4d6f99','#c3d2e5':'#334255','#eaf4fd':'#2c3c52','#f2f8fd':'#2c3c52','#e5f1fb':'#26354a',
'#b8d6fb':'#4d6f99','#dcebfc':'#2b4a6a','#c1dbfc':'#24405e','#7da2ce':'#5a85bb','#f6f6f6':'#4a4f57','#ececec':'#3f444b',
'#dcdcdc':'#33373d','#cfcfcf':'#2c3035','#707070':'#121315','#f6f9fd':'#232a33','#fffbe6':'#3a3420','#abadb3':'#4a515b',
'#8e8f8f':'#5a616b','#8d8d8d':'#8a9099','#3a5a85':'#a9c4e8','#2b4c74':'#a9c4e8','#fdfeff':'#33455c','#e3effb':'#2a3a4f',
'#e8f2fc':'#2f4057','#d7e8fa':'#28374b','#e3effc':'#2b3b50','#9fc3e8':'#4d6f99','#a5a5a5':'#555a61','#fffbe0':'#3a3420',
'#fff2b8':'#332d18','#e3cf7a':'#6b5a20','#a8a8a8':'#7c828b','#9a9a9a':'#7c828b','#f1f7fd':'#2c3c52','#f7fafd':'#273240',
'#eef5fc':'#2c3c52','#595959':'#b8bec6','#a7a7a7':'#6c727a','#3d8fd6':'#5aa6ea','#0066cc':'#6cb4ff','#0088e4':'#7cc4ff',
'#c9def4':'#22324a','#d9e8f8':'#1d2a3c','#e9f2fb':'#192330'}
hexre=r'#[0-9a-fA-F]{6}\b|#[0-9a-fA-F]{3}\b'
def decl(mo):
    prop,val=mo.group(1),mo.group(2)
    if prop.strip()=='color' and re.fullmatch(r'\s*#fff(fff)?\s*(!important)?\s*',val,re.I):
        return mo.group(0)          # white text stays white (badges, title band, Send label…)
    return prop+':'+re.sub(hexre,lambda x:m.get(x.group(0).lower(),x.group(0)),val)
s=re.sub(r'([\w-]+\s*):([^;{}]*)',decl,s)
s=s.replace('rgba(255, 255, 255, 0.9)','rgba(120, 160, 220, 0.22)').replace('rgba(246, 250, 255,','rgba(43, 54, 70,').replace('rgba(255, 255, 255, 0)','rgba(31, 34, 40, 0)')
s=s.replace('rgba(255, 255, 255, 0.8)','rgba(255, 255, 255, 0.12)')
s+='''
/* dark: the swirl is a light picture, so it's left out; Discord's own icons in a light grey */
#app-mount .panels__5e434 { background: var(--wlm-header) !important; }
#app-mount .subtitleContainer_f75fb0 .toolbar__9293f .iconWrapper__9293f,
#app-mount .channelTextArea_f75fb0 .buttons__74017,
#app-mount .panels__5e434 .buttons__37e49 { color: #c9d6e8 !important; }
#app-mount [class*="numberBadge_"], #app-mount [class*="textBadge_"] { color: #ffffff !important; }
'''
open('src/messenger-dark.css','w').write(s)
