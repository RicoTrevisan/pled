[
    {"PLUGIN_ID", "1670612027178x122079323974008830"},
    {"COOKIE",
   "meta_live_u2main=bus|1497412725082x768880828050896500|1750048021536x220029180249619700; meta_live_u2main.sig=U9mt8OoZejwGDM-m5jTXfDPMdAw; meta_u1main=1497412725082x768880828050896500;"}
]
|> Enum.each(fn {key, value} -> System.put_env(key, value) end)
