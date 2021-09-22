import io
import os
from re import S


class TokenError(Exception):
    pass


class BaseNode:
    def __init__(self, start, end):
        self.name = None
        self.start = start
        self.end = end

    def __repr__(self):
        cls_name = self.__class__.__name__
        return f'<{cls_name} >'

class CMDNode(BaseNode):
    def __init__(self, start, end, is_global, value):
        super().__init__(start, end)
        self.is_global = is_global
        self.value = value

    def __repr__(self):
        cls_name = self.__class__.__name__
        brief = repr(self.value)[:30]
        return f'<{cls_name} cmd={brief}>'


class FuncNode(BaseNode):
    def __init__(self, name, start, end, is_global, value):
        super().__init__(start, end)
        self.name = name
        self.is_global = is_global
        self.value = value

    def __repr__(self):
        cls_name = self.__class__.__name__
        brief = repr(self.value)[:30]
        return f'<{cls_name} name={self.name} value={brief}>'


class VarNode(BaseNode):
    def __init__(self, name, start, end, is_global, value):
        super().__init__(start, end)
        self.name = name
        self.is_global = is_global
        self.value = value

    def __repr__(self):
        cls_name = self.__class__.__name__
        brief = repr(self.value)[:30] if type(self.value) is str else self.value 
        return f'<{cls_name} name={self.name} value={brief}>'


class CommentNode(BaseNode):
    pass


class ReturnNode(BaseNode):
    def __init__(self, start, end, value):
        super().__init__(start, end)
        self.name = 'return'
        self.value = value


class PackageParser:
    BUFFERING = 512

    TOKEN_COMMENT = "#"
    TOKEN_LOCAL = ":local "
    TOKEN_GLOBAL = ":global "
    TOKEN_RETURN = ":return "
    TOKEN_CMD = ":"
    TOKEN_FUNC = "do={"
    TOKEN_BRACE_END = "}"
    TOKEN_DELIMITER = ";"
    TOKEN_VAR_ARRAY = "{"
    TOKEN_VAR_ARRAY_END = "}"
    TOKEN_VAR_TRUE = "true"
    TOKEN_VAR_FALSE = "false"
    TOKEN_VAR_QUOTE = "$"
    TOKEN_VAR_BRACKET = "("
    TOKEN_VAR_BRACKET_END = ")"
    TOKEN_VAR_CMD = "["
    TOKEN_VAR_CMD_END = "]"

    def __init__(self, name):
        self.name = name
        self._nodes = []
        self._nodes_mapping = {}
        self._stream = None

    @classmethod
    def from_file(cls, path):
        _, file_name = os.path.split(path)
        pkg_name, _ = os.path.splitext(file_name)
        pkg_name = pkg_name.replace("_", ".")
        inst = cls(pkg_name)
        f = open(path, 'rb', buffering=cls.BUFFERING)
        inst(f)
        return inst

    @classmethod
    def from_string(cls, text):
        inst = cls()
        with io.StringIO(text) as f:
            inst(f)
        return inst

    @property
    def stream(self):
        return self._stream

    def peek(self, num=1):
        buffered = self.stream.peek().decode()
        if buffered:
            return buffered[0:num]
        return ""

    def peek_all(self):
        buffered = self.stream.peek().decode()
        if len(buffered) < 100:
            pos = self.stream.tell()
            self.stream.read(512)
            self.stream.seek(pos)
        return buffered

    def read(self, num=1):
        return self.stream.read(num).decode()

    def append_node(self, node):
        self._nodes.append(node)
        self._nodes_mapping[node.name] = node

    def __call__(self, stream: io.BufferedReader):
        self._stream = stream
        while True:
            ch = self.peek()
            buffered = self.peek_all()
            if not ch:
                break
            # handle
            if ch in {"\n", "\r", "\t", " "}:
                self.skip_whitespace()
            # token
            elif buffered.startswith(self.TOKEN_COMMENT):
                self.parse_comment()
            elif buffered.startswith(self.TOKEN_LOCAL):
                self.parse_local()
            elif buffered.startswith(self.TOKEN_GLOBAL):
                self.parse_global()
            elif buffered.startswith(self.TOKEN_RETURN):
                self.parse_return()
            elif buffered.startswith(self.TOKEN_CMD):
                self.parse_cmd()
            else:
                raise ValueError(f"package: {self.name} unexpected token, {repr(buffered)}")

    def skip_line(self):
        while True:
            ch = self.read()
            if ch == '' or ch == '\n':
                break

    def skip_delimiter(self):
        if self.peek() == self.TOKEN_DELIMITER:
            self.read()

    def skip_token(self, token):
        self.read(len(token))

    def skip_whitespace_line(self):
        while True:
            ch = self.peek()
            if ch == '':
                break
            if ch in {"\n", "\r", "\t", " "}:
                self.read()
                if ch == '\n':
                    break
            else:
                break

    def skip_whitespace_inline(self):
        while True:
            ch = self.peek()
            if ch in {"\r", "\t", " "}:
                self.read()
            else:
                break

    def skip_whitespace(self):
        while True:
            ch = self.peek()
            if ch in {"\n", "\r", "\t", " "}:
                self.read()
            else:
                break

    def skip_quote(self):
        while True:
            ch = self.read()
            if ch == '':
                raise TokenError("unexpected end")
            elif ch == '\\':
                self.read()
            elif ch == '"':
                break
            else:
                continue

    def skip_brace(self):
        count = 1
        while True:
            if count == 0:
                break
            ch = self.read()
            if ch == '':
                raise TokenError("unexpected end")
            elif ch == '"':
                self.skip_quote()
            elif ch == '}':
                count -= 1
            elif ch == '{':
                count += 1
            else:
                continue

    def parse_comment(self):
        self.stream.read(len(self.TOKEN_COMMENT))
        self.skip_line()

    def parse_var_name(self):
        name = ''
        while True:
            ch = self.peek()
            cho = ord(ch)
            if (48 <= cho <= 57) or (65 <= cho <= 122):
                self.read()
                name = f'{name}{ch}'
            elif ch in {"\n", "\r", "\t", " ", self.TOKEN_DELIMITER}:
                return name
            else:
                raise TokenError(f"variable name error, got: {ch}")

    def parse_local(self):
        start = self.stream.tell()
        self.skip_token(self.TOKEN_LOCAL)
        name = self.parse_var_name()
        self.skip_whitespace()
        buffered = self.peek_all()
        if buffered.startswith(self.TOKEN_FUNC):
            self.parse_func(name, start)
        else:
            self.parse_var(name, start)

    def parse_global(self):
        start = self.stream.tell()
        self.skip_token(self.TOKEN_GLOBAL)
        name = self.parse_var_name()
        self.skip_whitespace()
        buffered = self.peek_all()
        if buffered.startswith(self.TOKEN_FUNC):
            self.parse_func(name, start, True)
        else:
            self.parse_var(name, start, True)

    def parse_cmd(self):
        s = ':'
        start = self.stream.tell()
        self.skip_token(self.TOKEN_CMD)
        while True:
            ch = self.read()
            s = f'{s}{ch}'
            if ch in {self.TOKEN_DELIMITER, '\n'}:
                break
        end = self.stream.tell()
        node = CMDNode(start, end, True, s)
        self.append_node(node)

    def parse_func(self, name, start, is_global=False):
        """parse_func
        :local func do={};
        """
        self.skip_token(self.TOKEN_FUNC)
        self.skip_brace()
        self.skip_delimiter()
        self.skip_whitespace_line()
        end = self.stream.tell()
        node = FuncNode(name, start, end, is_global, "TODO: ")
        self.append_node(node)

    def parse_var(self, name, start, is_global=False):
        """parse_var
        :local var {};
        """
        result = self.parse_var_switch()
        self.skip_delimiter()
        self.skip_whitespace_line()
        end = self.stream.tell()
        node = VarNode(name, start, end, is_global, result)
        self.append_node(node)

    def parse_var_switch(self):
        buffered = self.peek_all()
        ch = buffered[0]
        if '0' <= ch <= '9':
            res = self.parse_var_num()
        elif buffered.startswith(self.TOKEN_VAR_ARRAY):
            res = self.parse_var_array()
        elif buffered.startswith("\""):
            res = self.parse_var_str()
        elif buffered.startswith(self.TOKEN_VAR_TRUE):
            res = self.parse_var_true()
        elif buffered.startswith(self.TOKEN_VAR_FALSE):
            res = self.parse_var_false()
        elif buffered.startswith(self.TOKEN_VAR_QUOTE):
            res = self.parse_var_quote()
        elif buffered.startswith(self.TOKEN_VAR_CMD):
            res = self.parse_var_cmd()
        elif buffered.startswith(self.TOKEN_VAR_BRACKET):
            res = self.parse_var_bracket()
        elif buffered.startswith(self.TOKEN_DELIMITER):
            res = ''
        else:
            import ipdb; ipdb.set_trace()
            res = self.parse_var_ambiguous()
        return res

    def parse_var_true(self):
        self.skip_token(self.TOKEN_VAR_TRUE)
        return True

    def parse_var_false(self):
        self.skip_token(self.TOKEN_VAR_FALSE)
        return False

    def parse_var_cmd(self):
        s = '['
        count = 1
        self.skip_token(self.TOKEN_VAR_CMD)
        while True:
            ch = self.read()
            s = f'{s}{ch}'
            if ch == "[":
                count += 1
            elif ch == ']':
                count -= 1
            if count == 0:
                return s

    def parse_var_ambiguous(self, ):
        """TODO:"""
        pos = self.stream.tell()
        buffered = self.peek_all()
        raise NotImplementedError(f"pos: {pos}, buffer: {buffered}")

    def parse_var_num(self):
        v = ''
        while True:
            ch = self.peek()
            if '0' <= ch <= '9':
                v = f'{v}{ch}'
                self.read()
            elif ch in {self.TOKEN_DELIMITER, self.TOKEN_VAR_ARRAY_END}:
                return int(v)
            elif ch in {'\n', '\r'}:
                return int(v)
            else:
                pos = self.stream.tell()
                buffered = self.peek_all()
                raise NotImplementedError(f"pos: {pos}, buffer: {buffered}")

    def parse_var_str(self):
        s = ''
        self.read()
        while True:
            ch = self.read()
            if ch == "\"":
                return s
            else:
                s = f'{s}{ch}'

    def parse_var_quote(self):
        self.skip_token(self.TOKEN_VAR_QUOTE)
        name = self.parse_var_name()
        node = self._nodes_mapping.get(name)
        if node is None:
            import ipdb; ipdb.set_trace()
            raise KeyError(f"Quoted variable: {name} cannot found")
        return node.value

    def parse_var_bracket(self):
        s = '('
        count = 1
        self.skip_token(self.TOKEN_VAR_BRACKET)
        while True:
            ch = self.read()
            s = f'{s}{ch}'
            if ch == self.TOKEN_VAR_BRACKET:
                count += 1
            elif ch == self.TOKEN_VAR_BRACKET_END:
                count -= 1
            if count == 0:
                return s

    def parse_var_array(self):
        result = []
        is_dict = None
        self.stream.read(len(self.TOKEN_VAR_ARRAY))
        while True:
            self.skip_whitespace()
            # break
            ch = self.peek()
            if ch == self.TOKEN_VAR_ARRAY_END:
                self.read()
                break
            # get k or v
            k = self.parse_var_switch()
            ch = self.peek()
            if ch == "=":
                self.read()
                if is_dict is None:
                    is_dict = True
                if is_dict is False:
                    raise TokenError("ambiguous array not support")
                v = self.parse_var_switch()
                result.append((k, v))
            else:
                if is_dict is None:
                    is_dict = False
                if is_dict is True:
                    raise TokenError("ambiguous array not support")
                result.append(k)
            # delimiter after item
            ch = self.peek()
            if ch == self.TOKEN_DELIMITER:
                self.read()
            elif ch == self.TOKEN_VAR_ARRAY_END:
                continue
            else:
                import ipdb; ipdb.set_trace()
                raise TokenError(f"expected delimiter, {ch}")
        # make result
        if is_dict:
            return dict(result)
        return result

    def parse_return(self):
        start = self.stream.tell()
        self.skip_token(self.TOKEN_RETURN)
        self.skip_whitespace_inline()
        result = self.parse_var_switch()
        self.skip_delimiter()
        self.skip_whitespace_line()
        end = self.stream.tell()
        node = ReturnNode(start, end, result)
        self.append_node(node)

    def get_return(self):
        node = self._nodes_mapping['return']
        return node

    def get_metainfo(self):
        node = self._nodes_mapping['metaInfo']
        return node

    def get_global_functions(self):
        result = []
        for node in self._nodes:
            if isinstance(node, FuncNode):
                if node.is_global:
                    result.append(node)
        return result

    def get_global_variables(self):
        result = []
        for node in self._nodes:
            if isinstance(node, VarNode):
                if node.is_global:
                    result.append(node)
        return result

    def get_global_commands(self):
        result = []
        for node in self._nodes:
            if isinstance(node, CMDNode):
                if node.is_global:
                    result.append(node)
        return result 