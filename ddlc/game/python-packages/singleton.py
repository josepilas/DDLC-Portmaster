class SingleInstanceException(BaseException):
    pass


class SingleInstance(object):
    def __init__(self, flavor_id=""):
        self.initialized = True

    def __del__(self):
        return None


def f(name):
    return None
