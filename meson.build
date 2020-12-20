project('betterclist', 'd')

sources = files(
  'source/betterclist.d',
)
incdir = include_directories('source')

betterclist = library('betterclist',
  sources,
  include_directories: incdir,
)

betterclist_dep = declare_dependency(include_directories: incdir, link_with: betterclist)
