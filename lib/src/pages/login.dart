// ignore_for_file: unused_import, avoid_print

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_chat_push_for_china/tencent_chat_push_for_china.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_list_pick.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_selection_theme.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_country.dart';

import 'package:tencent_cloud_chat_demo/src/config.dart';
import 'package:tencent_cloud_chat_demo/src/pages/home_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/privacy/privacy_webview.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:tencent_cloud_chat_demo/src/util/smsLogin.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/login_captcha.dart';

import '../../utils/GenerateUserSig.dart';
import '../../utils/commonUtils.dart';
import '../../utils/toast.dart';

class LoginPage extends StatelessWidget {
  final Function? initIMSDK;
  const LoginPage({Key? key, this.initIMSDK}) : super(key: key);

  removeLocalSetting() async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    SharedPreferences prefs = await _prefs;
    prefs.remove("smsLoginToken");
    prefs.remove("smsLoginPhone");
    prefs.remove("smsLoginUserID");
    prefs.remove("channelListMain");
    prefs.remove("discussListMain");
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: Scaffold(
          body: AppLayout(initIMSDK: initIMSDK),
          resizeToAvoidBottomInset: false,
        ));
  }
}

class AppLayout extends StatelessWidget {
  final Function? initIMSDK;
  const AppLayout({Key? key, this.initIMSDK}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      },
      child: Stack(
        children: [
          const AppLogo(),
          LoginForm(
            initIMSDK: initIMSDK,
          ),
        ],
      ),
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
                    theme.primaryColor ?? CommonColor.primaryColor
                  ]),
            ),
            child: Image.asset("assets/hero_image.png")),
        Positioned(
          child: Container(
            padding: EdgeInsets.only(top: height / 30, left: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: CommonUtils.adaptWidth(380),
                  width: CommonUtils.adaptWidth(140),
                  child: const Image(
                    image: AssetImage("assets/logo_transparent.png"),
                  ),
                ),
                Expanded(
                    child: Container(
                  margin: const EdgeInsets.only(right: 5),
                  height: CommonUtils.adaptHeight(220),
                  padding: const EdgeInsets.only(top: 10, left: 12, right: 15),
                  child: Column(
                    children: <Widget>[
                      Text(
                        TIM_t("腾讯云即时通信IM"),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: CommonUtils.adaptFontSize(58),
                        ),
                      ),
                      Text(
                        TIM_t("欢迎使用本 APP 体验腾讯云 IM 产品服务"),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: CommonUtils.adaptFontSize(26),
                        ),
                      ),
                    ],
                    crossAxisAlignment: CrossAxisAlignment.start,
                  ),
                )),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class LoginForm extends StatefulWidget {
  final Function? initIMSDK;
  const LoginForm({Key? key, required this.initIMSDK}) : super(key: key);

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final CoreServicesImpl coreInstance = TIMUIKitCore.getInstance();

  String userID = '';

  @override
  initState() {
    super.initState();
    checkFirstEnter();
    initService();
  }

  @override
  void dispose() {
    userSigEtController.dispose();
    telEtController.dispose();
    super.dispose();
  }

  bool isGeted = false;
  String tel = '';
  int timer = 60;
  String sessionId = '';
  String code = '';
  bool isValid = false;
  TextEditingController userSigEtController = TextEditingController();
  TextEditingController telEtController = TextEditingController();
  String dialCode = "+86";
  String countryName = TIM_t("中国大陆");

  void initService() {
    if (widget.initIMSDK != null) {
      widget.initIMSDK!();
    }
    userSigEtController.addListener(checkIsValidForm);
    telEtController.addListener(checkIsValidForm);
    SmsLogin.initLoginService();
    setTel();
  }

  void checkIsValidForm() {
    if (userSigEtController.text.isNotEmpty &&
        telEtController.text.isNotEmpty) {
      setState(() {
        isValid = true;
      });
    } else if (isValid) {
      setState(() {
        isValid = false;
      });
    }
  }

  void setTel() async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    SharedPreferences prefs = await _prefs;
    String? phone = prefs.getString("smsLoginPhone");
    if (phone != null) {
      telEtController.value = TextEditingValue(
        text: phone,
      );
      setState(() {
        tel = phone;
      });
    }
  }

  void timeDown() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        if (timer == 0) {
          setState(() {
            timer = 60;
            isGeted = false;
          });
          return;
        }
        setState(() {
          timer = timer - 1;
        });
        timeDown();
      }
    });
  }

  TextSpan webViewLink(String title, String url) {
    return TextSpan(
      text: TIM_t(title),
      style: const TextStyle(
        color: Color.fromRGBO(0, 110, 253, 1),
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PrivacyDocument(title: title, url: url)));
        },
    );
  }

  void checkFirstEnter() async {
    Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
    SharedPreferences prefs = await _prefs;
    String? firstTime = prefs.getString("firstTime");
    if (firstTime != null && firstTime == "true") {
      return;
    }
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8))),
          content: Text.rich(
            TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Colors.black, height: 2.0),
                children: [
                  TextSpan(
                    text: TIM_t(
                        "欢迎使用腾讯云即时通信 IM，为保护您的个人信息安全，我们更新了《隐私政策》，主要完善了收集用户信息的具体内容和目的、增加了第三方SDK使用等方面的内容。"),
                  ),
                  const TextSpan(
                    text: "\n",
                  ),
                  TextSpan(
                    text: TIM_t("请您点击"),
                  ),
                  webViewLink("《用户协议》",
                      'https://web.sdk.qcloud.com/document/Tencent-IM-User-Agreement.html'),
                  TextSpan(
                    text: TIM_t(", "),
                  ),
                  webViewLink("《隐私协议》",
                      'https://privacy.qq.com/document/preview/1cfe904fb7004b8ab1193a55857f7272'),
                  TextSpan(
                    text: TIM_t(", "),
                  ),
                  webViewLink("《信息收集清单》",
                      'https://privacy.qq.com/document/preview/45ba982a1ce6493597a00f8c86b52a1e'),
                  TextSpan(
                    text: TIM_t("和"),
                  ),
                  webViewLink("《信息共享清单》",
                      'https://privacy.qq.com/document/preview/dea84ac4bb88454794928b77126e9246'),
                  TextSpan(
                      text: TIM_t("并仔细阅读，如您同意以上内容，请点击“同意并继续”，开始使用我们的产品与服务！")),
                ]),
            overflow: TextOverflow.clip,
          ),
          actions: [
            CupertinoDialogAction(
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 100, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(0, 110, 253, 1),
                    borderRadius: BorderRadius.all(
                      Radius.circular(24),
                    ),
                  ),
                  child: Text(TIM_t("同意并继续"),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16))),
              onPressed: () {
                prefs.setString("firstTime", "true");
                Navigator.of(context).pop(true);
              },
            ),
            CupertinoDialogAction(
              child: Text(TIM_t("不同意并退出"),
                  style: const TextStyle(color: Colors.grey, fontSize: 16)),
              isDestructiveAction: true,
              onPressed: () {
                exit(0);
              },
            ),
          ],
        );
      },
    );
  }

  directToHomePage() {
    Routes().directToHomePage();
  }

  smsFirstLogin() async {
    if (tel == '' && IMDemoConfig.productEnv) {
      ToastUtils.toast(TIM_t("请输入手机号"));
    }
    if (sessionId == '' || code == '') {
      ToastUtils.toast(TIM_t("验证码异常"));
      return;
    }
    String phoneNum = "$dialCode$tel";
    Map<String, dynamic> response = await SmsLogin.smsFirstLogin(
      sessionId: sessionId,
      phone: phoneNum,
      code: code,
    );
    int errorCode = response['errorCode'];
    String errorMessage = response['errorMessage'];

    if (errorCode == 0) {
      Map<String, dynamic> datas = response['data'];
      // userId, sdkAppId, sdkUserSig, token, phone:tel
      String userId = datas['userId'];
      String userSig = datas['sdkUserSig'];
      String token = datas['token'];
      String phone = datas['phone'];
      String avatar = datas['avatar'];
      int sdkAppId = datas['sdkAppId'];

      var data = await coreInstance.login(
        userID: userId,
        userSig: userSig,
      );
      if (data.code != 0) {
        final option1 = data.desc;
        ToastUtils.toast(
            TIM_t_para("登录失败{{option1}}", "登录失败$option1")(option1: option1));
        return;
      }

      final userInfos = coreInstance.loginUserInfo;
      if (userInfos != null) {
        await coreInstance.setSelfInfo(
          userFullInfo: V2TimUserFullInfo.fromJson(
            {
              "nickName": userId,
              "faceUrl": avatar,
            },
          ),
        );
      }

      Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
      SharedPreferences prefs = await _prefs;
      prefs.setString("smsLoginToken", token);
      prefs.setString("smsLoginPhone", phone.replaceFirst(dialCode, ""));
      prefs.setString("smsLoginUserID", userId);
      prefs.setString("sdkAppId", sdkAppId.toString());
      setState(() {
        tel = '';
        code = '';
        timer = 60;
        isGeted = false;
      });
      userSigEtController.clear();
      telEtController.clear();
      // await getIMData();
      // TIMUIKitConversationController().loadData();
      // Navigator.pop(context);
      directToHomePage();
    } else {
      ToastUtils.toast(errorMessage);
    }
  }

  // 获取验证码
  getLoginCode(context) async {
    if (tel.isEmpty) {
      ToastUtils.toast(TIM_t("请输入手机号"));
      return;
    } else if (!RegExp(r"1[0-9]\d{9}$").hasMatch(tel)) {
      ToastUtils.toast(TIM_t("手机号格式错误"));
      return;
    } else {
      await _showMyDialog();
    }
  }

  // 验证验证码后台下发短信
  void verifyPicture(messageObj) async {
    // String captchaWebAppid =
    //     Provider.of<AppConfig>(context, listen: false).appid;
    String phoneNum = "$dialCode$tel";
    final sdkAppid = IMDemoConfig.sdkappid.toString();
    print("sdkAppID$sdkAppid");
    Map<String, dynamic> response = await SmsLogin.vervifyPicture(
      phone: phoneNum,
      ticket: messageObj['ticket'],
      randstr: messageObj['randstr'],
      appId: sdkAppid,
    );
    int errorCode = response['errorCode'];
    String errorMessage = response['errorMessage'];
    if (errorCode == 0) {
      Map<String, dynamic> res = response['data'];
      String sid = res['sessionId'];
      setState(() {
        isGeted = true;
        sessionId = sid;
      });
      timeDown();
      ToastUtils.toast(TIM_t("验证码发送成功"));
    } else {
      ToastUtils.toast(errorMessage);
    }
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          elevation: 0,
          content: SingleChildScrollView(
              child: LoginCaptcha(
                  onSuccess: verifyPicture,
                  onClose: () {
                    Navigator.pop(context);
                  })),
        );
      },
    );
  }

  userLogin() async {
    if (userID.trim() == '') {
      ToastUtils.toast(TIM_t("请输入用户名"));
      return;
    }

    String key = IMDemoConfig.key;
    int sdkAppId = IMDemoConfig.sdkappid;
    if (key == "") {
      ToastUtils.toast(TIM_t("请在环境变量中写入key"));
      return;
    }
    GenerateTestUserSig generateTestUserSig = GenerateTestUserSig(
      sdkappid: sdkAppId,
      key: key,
    );

    String userSig =
        generateTestUserSig.genSig(identifier: userID, expire: 99999);

    var data = await coreInstance.login(
      userID: userID,
      userSig: userSig,
    );
    if (data.code != 0) {
      final option1 = data.desc;
      ToastUtils.toast(
          TIM_t_para("登录失败{{option1}}", "登录失败$option1")(option1: option1));
      return;
    }
    directToHomePage();
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: const Size(750, 1624),
      minTextAdapt: true,
    );

    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Stack(
      children: [
        Positioned(
            bottom: CommonUtils.adaptHeight(200),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              decoration: const BoxDecoration(
                //背景
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                    bottomLeft: Radius.circular(30.0),
                    bottomRight: Radius.circular(30.0)),
                //设置四周边框
              ),
              // color: Colors.white,
              height: MediaQuery.of(context).size.height -
                  CommonUtils.adaptHeight(600),

              width: MediaQuery.of(context).size.width,
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //TODO 按照获取验证码状态来切换展示
                    // Padding(
                    //   padding:
                    //       EdgeInsets.only(top: CommonUtils.adaptFontSize(34)),
                    //   child: Text(
                    //     TIM_t("用户名"),
                    //     style: TextStyle(
                    //       fontWeight: FontWeight.w700,
                    //       fontSize: CommonUtils.adaptFontSize(34),
                    //     ),
                    //   ),
                    // ),
                    // TextField(
                    //   autofocus: false,
                    //   decoration: InputDecoration(
                    //     contentPadding:
                    //         EdgeInsets.only(left: CommonUtils.adaptWidth(14)),
                    //     hintText: TIM_t("请输入用户名"),
                    //     hintStyle:
                    //         TextStyle(fontSize: CommonUtils.adaptFontSize(32)),
                    //     //
                    //   ),
                    //   keyboardType: TextInputType.number,
                    //   onChanged: (v) {
                    //     setState(() {
                    //       userID = v;
                    //     });
                    //   },
                    // ),
                    Text(
                      TIM_t("国家/地区"),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: CommonUtils.adaptFontSize(34)),
                    ),
                    CountryListPick(
                      appBar: AppBar(
                        // backgroundColor: Colors.blue,
                        title: Text(TIM_t("选择你的国家区号"),
                            style: const TextStyle(fontSize: 17)),
                        flexibleSpace: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              theme.lightPrimaryColor ??
                                  CommonColor.lightPrimaryColor,
                              theme.primaryColor ?? CommonColor.primaryColor
                            ]),
                          ),
                        ),
                      ),

                      // if you need custome picker use this
                      pickerBuilder: (context, CountryCode? countryCode) {
                        return Row(
                          children: [
                            // 屏蔽伊朗 98
                            // 朝鲜 82 850
                            // 叙利亚 963
                            // 古巴 53
                            Text(
                                "${countryName == "China" ? "中国大陆" : countryName}(${countryCode?.dialCode})",
                                style: TextStyle(
                                    color: const Color.fromRGBO(17, 17, 17, 1),
                                    fontSize: CommonUtils.adaptFontSize(32))),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Color.fromRGBO(17, 17, 17, 0.8),
                            ),
                          ],
                        );
                      },

                      // To disable option set to false
                      theme: CountryTheme(
                          isShowFlag: false,
                          isShowTitle: true,
                          isShowCode: true,
                          isDownIcon: true,
                          showEnglishName: true,
                          searchHintText: TIM_t("请使用英文搜索"),
                          searchText: TIM_t("搜索")),
                      // Set default value
                      initialSelection: '+86',
                      onChanged: (code) {
                        setState(() {
                          dialCode = code?.dialCode ?? "+86";
                          countryName = code?.name ?? TIM_t("中国大陆");
                        });
                      },
                      useUiOverlay: false,
                      // Whether the country list should be wrapped in a SafeArea
                      useSafeArea: false,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                              BorderSide(width: 1, color: Colors.grey))),
                    ),
                    Padding(
                      padding:
                      EdgeInsets.only(top: CommonUtils.adaptFontSize(34)),
                      child: Text(
                        TIM_t("手机号"),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: CommonUtils.adaptFontSize(34),
                        ),
                      ),
                    ),
                    TextField(
                      controller: telEtController,
                      decoration: InputDecoration(
                        contentPadding:
                        EdgeInsets.only(left: CommonUtils.adaptWidth(14)),
                        hintText: TIM_t("请输入手机号"),
                        hintStyle:
                        TextStyle(fontSize: CommonUtils.adaptFontSize(32)),
                        //
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (v) {
                        setState(() {
                          tel = v;
                        });
                      },
                    ),
                    Padding(
                        child: Text(
                          TIM_t("验证码"),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: CommonUtils.adaptFontSize(34)),
                        ),
                        padding: EdgeInsets.only(
                          top: CommonUtils.adaptHeight(35),
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: userSigEtController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.only(left: 5),
                              hintText: TIM_t("请输入验证码"),
                              hintStyle: TextStyle(
                                  fontSize: CommonUtils.adaptFontSize(32)),
                            ),
                            keyboardType: TextInputType.number,
                            //校验密码
                            onChanged: (value) {
                              if ('$code$code' == value && value.length > 5) {
                                //键入重复的情况
                                setState(() {
                                  userSigEtController.value = TextEditingValue(
                                    text: code, //不赋值新的 用旧的;
                                    selection: TextSelection.fromPosition(
                                      TextPosition(
                                          affinity: TextAffinity.downstream,
                                          offset: code.length),
                                    ), //  此处是将光标移动到最后,
                                  );
                                });
                              } else {
                                //第一次输入验证码
                                setState(() {
                                  userSigEtController.value = TextEditingValue(
                                    text: value,
                                    selection: TextSelection.fromPosition(
                                      TextPosition(
                                          affinity: TextAffinity.downstream,
                                          offset: value.length),
                                    ), //  此处是将光标移动到最后,
                                  );
                                  code = value;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: CommonUtils.adaptWidth(200),
                          child: ElevatedButton(
                            child: isGeted
                                ? Text(timer.toString())
                                : Text(
                              TIM_t("获取验证码"),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: CommonUtils.adaptFontSize(24),
                              ),
                            ),
                            onPressed: isGeted
                                ? null
                                : () {
                              //获取验证码
                              FocusScope.of(context).unfocus();
                              getLoginCode(context);
                            },
                          ),
                        )
                      ],
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: CommonUtils.adaptHeight(46),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              child: Text(TIM_t("登录")),
                              // onPressed: userLogin,//TODO 先手机验证码，后用户名
                              onPressed: isValid ? smsFirstLogin : null,
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(),
                    )
                  ],
                ),
              ),
            ))
      ],
    );
  }
}
