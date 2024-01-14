import IPython

ipython = IPython.get_ipython()
if ipython is not None:
    ipython_version = IPython.__version__
    major_version = int(ipython_version.split('.')[0])
    minor_version = int(ipython_version.split('.')[1])

    if major_version < 8 or (major_version == 8 and minor_version < 1):
        ipython.magic("load_ext autoreload")
        ipython.magic("autoreload 2")
    else:
        ipython.run_line_magic(magic_name="load_ext", line="autoreload")
        ipython.run_line_magic(magic_name="autoreload", line="2")

    print("Autoreload enabled.")
else:
    print("Autoreload not enabled.")
